{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.git;

  # Build-time-generated .gitattributes covering every language mergiraf
  # currently supports. Stays in sync with the installed mergiraf version.
  mergirafAttributes = pkgs.runCommand "mergiraf-gitattributes" { } ''
    ${pkgs.mergiraf}/bin/mergiraf languages --gitattributes > $out
  '';

  # 1Password's dedicated SSH signing helper. On macOS the private key never
  # leaves the vault and the agent does not serve raw signature requests to
  # arbitrary callers -- pointing gpg.ssh.program here is what makes `git
  # commit -S` work, rather than relying on ssh-keygen reaching the agent.
  opSshSign = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
in
{
  options = {
    apps.cli.git.enable = lib.mkEnableOption "git, signing, and related tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      git-filter-repo
      mergiraf
    ];

    home-manager.users.${globals.user.name} = {
      programs = {
        fish.shellAliases = {
          # core
          g = "git";
          ga = "git add";
          gaa = "git add -A";
          gc = "git commit";
          gcm = "git commit -m";
          gp = "git push";
          gpf = "git push --force-with-lease";
          gpl = "git pull";
          gf = "git fetch";
          gd = "git diff";
          gds = "git diff --staged";
          gs = "git status";
          # branching
          gb = "git branch";
          gco = "git checkout";
          gsw = "git switch";
          gm = "git merge";
          # log
          glog = "git log --oneline --graph --decorate";
          glast = "git log -1 HEAD";
          # stash
          gsta = "git stash";
          gstp = "git stash pop";
          gstl = "git stash list";
          # rebase
          grb = "git rebase";
          grbc = "git rebase --continue";
          grba = "git rebase --abort";
          # misc
          gcp = "git cherry-pick";
          gcl = "git clone";
          gwip = "git commit -am 'WIP'";
          gundo = "git reset --soft HEAD~1";
          # tools
          lg = "lazygit";
        };

        git = {
          enable = true;
          settings = {
            user = {
              inherit (globals.user) email;
              name = globals.user.fullName;
              # A file rather than nixerator's ~/.ssh/id_ed25519.pub: no private
              # keys are materialised on this Mac at all -- 1Password holds them
              # and serves them over its agent -- so the public half is written
              # from globals below instead of being assumed to exist on disk.
              signingkey = "~/.config/git/signing_key.pub";
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            push = {
              default = "simple";
              autoSetupRemote = true;
              followTags = true;
            };
            merge = {
              ff = "only";
              conflictStyle = "diff3";

              # mergiraf -- syntax-aware merge driver. Triggered per-file by
              # ~/.config/git/attributes (managed below).
              mergiraf = {
                name = "mergiraf";
                driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
              };
            };
            rebase = {
              autoStash = true;
              updateRefs = true;
            };
            branch = {
              autoSetupRebase = "always";
              sort = "-committerdate";
            };
            rerere.enabled = true;
            fetch.prune = true;
            diff.algorithm = "histogram";
            core.excludesFile = "~/.config/git/ignore";

            # No mkForce needed here, unlike nixerator: that override exists to
            # beat programs.kitty's competing mkDefault, and kitty isn't
            # installed on this host.
            diff.tool = "difftastic";
            difftool.difftastic.cmd = ''${lib.getExe pkgs.difftastic} --background=dark --color=always "$LOCAL" "$REMOTE"'';

            # SSH signing, brokered by 1Password (see opSshSign above).
            commit.gpgsign = true;
            tag.gpgsign = true;
            gpg.format = "ssh";
            gpg.ssh.program = opSshSign;
            gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";

            # Git aliases (for use as `git <alias>`)
            alias = {
              a = "add";
              aa = "add -A";
              c = "commit";
              cm = "commit -m";
              co = "checkout";
              sw = "switch";
              st = "status";
              br = "branch";
              df = "diff";
              dfs = "diff --staged";
              gdt = "difftool -y -t difftastic";
              gdts = "difftool -y -t difftastic --staged";
              lg = "log --oneline --graph --decorate";
              ll = "log --oneline -n 20";
              last = "log -1 HEAD";
              unstage = "reset HEAD --";
              amend = "commit --amend --no-edit";
              undo = "reset --soft HEAD~1";
              wip = "commit -am 'WIP'";
              ss = "stash";
              sp = "stash pop";
              sl = "stash list";
              cp = "cherry-pick";
              rb = "rebase";
              rbc = "rebase --continue";
              rba = "rebase --abort";
              pf = "push --force-with-lease";
            };
          };
        };

        difftastic = {
          enable = true;
          # Wired by hand above via difftool.difftastic.cmd, matching nixerator.
          git.enable = false;
          options = {
            background = "dark";
            color = "always";
          };
        };

        lazygit = {
          enable = true;
          settings = {
            git.parseEmoji = true;
            gui.theme = {
              lightTheme = false;
              nerdFontVersion = "3";
            };
          };
        };

        gh = {
          enable = true;
          gitCredentialHelper.enable = true;
          settings = {
            editor = lib.getExe pkgs.${globals.preferences.editor};
            git_protocol = "ssh";
            prompt = "enabled";
            aliases = {
              co = "pr checkout";
              pv = "pr view";
              prs = "pr list";
              mine = "pr list --author @me";
              rv = "pr review";
              run = "run list";
              rw = "run watch";
            };
          };
        };
      };

      home.file = {
        # The public half of the 1Password-held signing key. Both git (as
        # user.signingkey) and ssh-keygen's verifier (via allowed_signers) need
        # it on disk; nothing here is secret.
        ".config/git/signing_key.pub".text = ''
          ${globals.git.gitPubSigningKey}
        '';

        # Lets `git log --show-signature` actually verify our own commits
        # instead of reporting "no principal matched".
        ".config/git/allowed_signers".text = ''
          ${globals.user.email} ${globals.git.gitPubSigningKey}
        '';

        ".config/git/ignore".text = ''
          .direnv/
          .DS_Store
          *.swp
          .helix/
          result
          result-*
        '';

        # Wire every mergiraf-supported file extension to the merge driver.
        ".config/git/attributes".source = mergirafAttributes;
      };
    };
  };
}
