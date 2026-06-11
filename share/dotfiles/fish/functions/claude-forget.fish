function claude-forget --description "Wipe Claude Code memory, history and trust for a directory"
    if not type -q python3
        echo "claude-forget: python3 is required but was not found in PATH." >&2
        return 1
    end

    set -l dir
    if set -q argv[1]
        set dir (realpath -- "$argv[1]")
    else
        set dir (realpath -- (pwd))
    end

    set -l slug (string replace -a -r '[/.]' '-' $dir)
    set -l projdir "$HOME/.claude/projects/$slug"

    echo "Target directory : $dir"
    echo "State folder     : $projdir"
    echo "JSON entry       : .projects[\"$dir\"] in ~/.claude.json"
    echo
    echo "Close every running Claude Code session first, in any directory."
    echo "Claude rewrites ~/.claude.json when a session exits, so an open"
    echo "session could undo the trust and permission reset performed here."
    echo

    read -l -P "Delete all of the above? [y/N] " ok
    or return 1
    if test "$ok" != y -a "$ok" != Y
        echo "Aborted."
        return 1
    end

    # Transcripts, session folders and the persistent memory directory.
    rm -rf -- "$projdir"

    # Trust acceptance and granted permissions live in the global config.
    # Drop just this directory's entry, rewriting the file atomically.
    python3 -c '
import json, os, sys
p = os.path.expanduser("~/.claude.json")
d = json.load(open(p))
d.get("projects", {}).pop(sys.argv[1], None)
tmp = p + ".tmp"
json.dump(d, open(tmp, "w"), indent=2)
os.replace(tmp, p)
' "$dir"

    echo "Done. The next Claude run in $dir starts fresh and asks to trust the folder."
end
