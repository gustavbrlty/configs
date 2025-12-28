{ pkgs }:

pkgs.writers.writeRustBin "sys-update" {} ''
    use std::env;
    use std::process::{Command, exit};
    use std::io::{self, Write};
    use std::sync::mpsc;
    use std::thread;
    use std::time::Duration;

    fn run_command_interactive(cmd: &str, args: &[&str]) {
        let status = Command::new(cmd)
            .args(args)
            .current_dir("/etc/nixos")
            .status()
            .expect("Échec de l'exécution de la commande");

        if !status.success() {
            eprintln!("!! Erreur lors de l'exécution de: {} {}", cmd, args.join(" "));
            exit(1);
        }
    }

    fn require_sudo_rights() {
        let status = Command::new("sudo")
            .arg("-v")
            .status()
            .expect("Impossible d'invoquer sudo");

        if !status.success() {
            eprintln!("Accès refusé (sudo requis).");
            exit(1);
        }
    }

    fn revert_lockfile() {
        let status = Command::new("sudo")
            .args(&["git", "restore", "flake.lock"])
            .current_dir("/etc/nixos")
            .status();

        if let Ok(s) = status {
            if !s.success() {
                eprintln!("!! [Attention] Impossible de restaurer flake.lock via Git.");
            }
        }
    }

    fn run_build_and_get_path() -> String {
        println!("\n== 2/4 Construction du système (analyse)... ==");
        
        let target = ".#nixosConfigurations.default.config.system.build.toplevel";

        let output = Command::new("nix")
            .args(&["build", target, "--print-out-paths", "--no-link"])
            .current_dir("/etc/nixos")
            .output()
            .expect("Échec de la commande nix build");

        if !output.status.success() {
            eprintln!("!! La construction a échoué.");
            io::stderr().write_all(&output.stderr).unwrap();
            revert_lockfile();
            exit(1);
        }

        let path = String::from_utf8(output.stdout).expect("Sortie invalide");
        path.trim().to_string()
    }

    // --- NOUVEAU : Compte à rebours visuel ---
    fn ask_confirmation_with_timeout() -> bool {
        print!("\nAppliquer ces changements ? [O/n] ");
        io::stdout().flush().unwrap();

        let (tx, rx) = mpsc::channel();

        // Thread d'écoute clavier
        thread::spawn(move || {
            let mut buffer = String::new();
            if io::stdin().read_line(&mut buffer).is_ok() {
                let _ = tx.send(buffer);
            }
        });

        // Boucle de 7 secondes
        for i in (1..=7).rev() {
            // \r ramène le curseur au début de la ligne, print! écrase le texte
            print!("\rAppliquer ces changements ? [O/n] (Validation auto dans {}s) ", i);
            io::stdout().flush().unwrap();

            // On attend une réponse pendant 1 seconde max à chaque tour de boucle
            match rx.recv_timeout(Duration::from_secs(1)) {
                Ok(input) => {
                    // L'utilisateur a répondu avant la fin
                    println!(); // Saut de ligne pour ne pas écraser le timer
                    let i = input.trim().to_lowercase();
                    if i == "n" || i == "non" || i == "no" {
                        return false;
                    }
                    return true;
                },
                Err(_) => {
                    // Timeout de 1 seconde écoulé, on continue la boucle
                    continue;
                }
            }
        }

        // Si on sort de la boucle, c'est que les 7 secondes sont passées
        println!("\n[Timer] Validation automatique.");
        return true;
    }

    fn main() {
        let args: Vec<String> = env::args().collect();
        if args.len() < 2 {
            eprintln!("Usage: sys-update [stable|all]");
            exit(1);
        }

        let mode = &args[1];

        match mode.as_str() {
            "stable" => {
                println!("== 1/4 Mise à jour des sources stables ==");
                run_command_interactive("sudo", &["nix", "flake", "update", "nixpkgs"]);
            },
            "all" => {
                require_sudo_rights();
                println!("== 1/4 Mise à jour de toutes les sources ==");
                run_command_interactive("sudo", &["nix", "flake", "update"]);
            },
            _ => {
                eprintln!("Mode inconnu. Utilisez 'stable' ou 'all'.");
                exit(1);
            }
        }

        let new_system_path = run_build_and_get_path();
        
        println!("\n== 3/4 Analyse des changements (nvd) ==");
        let nvd_path = "${pkgs.nvd}/bin/nvd";
        
        let _ = Command::new(nvd_path)
            .args(&["diff", "/run/current-system", &new_system_path])
            .status();

        if ask_confirmation_with_timeout() {
            println!("\n== 4/4 Application des changements (Switch) ==");
            run_command_interactive("sudo", &["nixos-rebuild", "switch", "--flake", ".#default"]);
            println!("\n[OK] Mise à jour terminée avec succès.");
        } else {
            println!("\n[Annulé] Aucun changement appliqué.\n");
            revert_lockfile();
            println!(":: Le fichier flake.lock est inchangé (restauré).");
            println!(":: Pour supprimer les paquets qui ont été téléchargés/compilés durant l'analyse,");
            println!("   vous pouvez lancer la commande : sudo nix-collect-garbage");
        }
    }
''
