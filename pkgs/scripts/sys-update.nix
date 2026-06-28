{ pkgs, selectableInputs ? [] }:

let
  lib = pkgs.lib;

  # Génère les lignes Rust du vec! de selectable_inputs() à partir de la
  # liste Nix `selectableInputs` (chaque élément : { key, desc }).
  # Produit par ex. :   ("nixpkgs", "Paquets stables"),
  inputsRust = lib.concatMapStringsSep "\n"
    (i: ''            ("${i.key}", "${i.desc}"),'')
    selectableInputs;
in

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

        // Boucle de 60 secondes
        for i in (1..=60).rev() {
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

        // Si on sort de la boucle, c'est que les 60 secondes sont passées
        println!("\n[Timer] Validation automatique.");
        return true;
    }

    // Liste des inputs sélectionnables : (clé de l'input flake, description).
    // CETTE LISTE EST GÉNÉRÉE AUTOMATIQUEMENT depuis `pinnedSpecs` et
    // `globalInputs` dans flake.nix. Ne pas l'éditer à la main.
    fn selectable_inputs() -> Vec<(&'static str, &'static str)> {
        vec![
${inputsRust}
        ]
    }

    // Menu interactif : l'utilisateur tape les numéros des inputs à mettre à jour.
    // Retourne la liste des clés d'inputs choisies.
    fn select_inputs_menu() -> Vec<String> {
        let inputs = selectable_inputs();

        println!("\n== Sélection des paquets/sources à mettre à jour ==\n");
        for (i, (key, desc)) in inputs.iter().enumerate() {
            println!("  [{:>2}] {:<14} - {}", i + 1, key, desc);
        }
        println!("\n  [ a] Tout mettre à jour");
        println!("  [ q] Annuler\n");
        print!("Entrez les numéros séparés par des espaces (ex: 3 5), 'a' ou 'q' : ");
        io::stdout().flush().unwrap();

        let mut buffer = String::new();
        io::stdin().read_line(&mut buffer).expect("Lecture échouée");
        let choice = buffer.trim().to_lowercase();

        if choice == "q" || choice.is_empty() {
            println!("\n[Annulé] Aucune sélection.");
            exit(0);
        }

        if choice == "a" {
            // Tout : on renvoie un marqueur vide => update global.
            return vec![];
        }

        let mut selected: Vec<String> = Vec::new();
        for token in choice.split_whitespace() {
            match token.parse::<usize>() {
                Ok(n) if n >= 1 && n <= inputs.len() => {
                    let key = inputs[n - 1].0.to_string();
                    if !selected.contains(&key) {
                        selected.push(key);
                    }
                },
                _ => {
                    eprintln!("!! Entrée invalide ignorée : '{}'", token);
                }
            }
        }

        if selected.is_empty() {
            eprintln!("!! Aucun input valide sélectionné.");
            exit(1);
        }

        println!("\n:: Inputs sélectionnés : {}", selected.join(", "));
        selected
    }

    fn main() {
        let args: Vec<String> = env::args().collect();
        if args.len() < 2 {
            eprintln!("Usage: sys-update [stable|all|select|<input>...]");
            eprintln!("  stable        : met à jour seulement nixpkgs (stable)");
            eprintln!("  all           : met à jour toutes les sources");
            eprintln!("  select        : menu interactif de sélection des paquets");
            eprintln!("  <input>...    : met à jour les inputs nommés (ex: pin-opencode)");
            exit(1);
        }

        let mode = &args[1];

        require_sudo_rights();

        match mode.as_str() {
            "stable" => {
                println!("== 1/4 Mise à jour des sources stables ==");
                run_command_interactive("sudo", &["nix", "flake", "update", "nixpkgs"]);
            },
            "all" => {
                // On met à jour explicitement chaque input connu, au lieu de
                // 'nix flake update' sans argument dont le comportement peut
                // laisser certains inputs déjà présents inchangés.
                println!("== 1/4 Mise à jour de toutes les sources ==");
                let mut cmd_args: Vec<&str> = vec!["nix", "flake", "update"];
                for (key, _) in selectable_inputs() {
                    cmd_args.push(key);
                }
                run_command_interactive("sudo", &cmd_args);
            },
            "select" => {
                let selected = select_inputs_menu();
                if selected.is_empty() {
                    println!("\n== 1/4 Mise à jour de toutes les sources ==");
                    let mut cmd_args: Vec<&str> = vec!["nix", "flake", "update"];
                    for (key, _) in selectable_inputs() {
                        cmd_args.push(key);
                    }
                    run_command_interactive("sudo", &cmd_args);
                } else {
                    println!("\n== 1/4 Mise à jour des paquets sélectionnés ==");
                    let mut cmd_args: Vec<&str> = vec!["nix", "flake", "update"];
                    for key in &selected {
                        cmd_args.push(key.as_str());
                    }
                    run_command_interactive("sudo", &cmd_args);
                }
            },
            _ => {
                // Mode "inputs nommés" : tous les arguments sont des clés d'inputs.
                let valid: Vec<&str> = selectable_inputs().iter().map(|(k, _)| *k).collect();
                let requested: Vec<String> = args[1..].to_vec();

                for key in &requested {
                    if !valid.contains(&key.as_str()) {
                        eprintln!("!! Input inconnu : '{}'", key);
                        eprintln!("   Inputs valides : {}", valid.join(", "));
                        exit(1);
                    }
                }

                println!("== 1/4 Mise à jour de : {} ==", requested.join(", "));
                let mut cmd_args: Vec<&str> = vec!["nix", "flake", "update"];
                for key in &requested {
                    cmd_args.push(key.as_str());
                }
                run_command_interactive("sudo", &cmd_args);
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
