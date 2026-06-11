
function __git_ref_name
    # Branch (normal case)
    set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
    if test -n "$branch"
        echo $branch
        return
    end

    # Exact tag (detached HEAD on tag)
    set -l tag (git describe --tags --exact-match 2>/dev/null)
    if test -n "$tag"
        echo $tag
        return
    end

    # Optional: if multiple tags exist, pick highest version
    set -l tags (git tag --points-at HEAD 2>/dev/null)
    if test -n "$tags"
        echo $tags | tr ' ' '\n' | sort -V | tail -n1
        return
    end

    # Fallback: short commit hash
    git rev-parse --short HEAD 2>/dev/null
end

function fish_prompt
    # =========================================
    # LAST COMMAND STATUS & DURATION
    # =========================================
    set -l last_status $status
    set -l last_duration_ms
    if test "$CMD_DURATION" -gt 500
        set last_duration_ms $CMD_DURATION
    end

    # Only show if command failed or took noticeable time
    if test $last_status -ne 0 -o -n "$last_duration_ms"
        echo
        # Execution time in dark gray
        if test $last_status -eq 0
            # Success: optionally italic
            set_color brblack --italic
            echo -n "-- executed in $last_duration_ms ms"
        else
            # Non-zero exit status: show text in red
            set_color red --bold
            echo -n "exit status: $last_status"

            # Reset to dark gray for duration part
            set_color brblack --italic
            if test -n "$last_duration_ms"
                echo -n " — executed in $last_duration_ms ms"
            end
        end

        # Reset colors and newline
        set_color normal
        echo
    end

    # =========================================
    # FIRST LINE - TIME, USER@HOST, PATH
    # =========================================
    set_color brblack  # time
    echo -n "["(date +%H:%M:%S)"] "

    set_color $fish_color_user
    echo -n (whoami)

    set_color $fish_color_host
    echo -n "@"(hostname)

    set_color $fish_color_cwd
    echo -n " "(prompt_pwd)

    # =========================================
    # GIT INFO
    # =========================================
    if type -q git
        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        if test -n "$git_root"
            set -l ahead 0
            set -l behind 0
            if git rev-parse @{u} >/dev/null 2>&1
                set ahead (git rev-list --count @{u}..HEAD 2>/dev/null)
                set behind (git rev-list --count HEAD..@{u} 2>/dev/null)
            end
            set -l staged (git diff --cached --name-only | wc -l | tr -d ' ')
            set -l unstaged (git diff --name-only | wc -l | tr -d ' ')
            set -l untracked (git -C "$git_root" ls-files --others --exclude-standard | wc -l | tr -d ' ')

            set_color brmagenta
            echo -n " (git:"

            set -l ref (__git_ref_name)

            # Color main/master branches specially
            if test "$ref" = "main" -o "$ref" = "master"
                set_color red
            else if git describe --tags --exact-match >/dev/null 2>&1
                # You're on a tag → different color (optional)
                set_color brgreen
            else if not git symbolic-ref HEAD >/dev/null 2>&1
                # Detached but not a tag → commit
                set_color bryellow
            end

            echo -n $ref
            # Branch
            #set -l branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)
            #if test "$branch" = "main" -o "$branch" = "master"
            #    set_color red
            #end
            #echo -n $branch

            # Ahead/behind
            if test $ahead -gt 0
                set_color brcyan
                echo -n " ↑$ahead"
            end
            if test $behind -gt 0
                set_color brblue
                echo -n " ↓$behind"
            end

            # Staged files
            if test $staged -gt 0
                set_color brgreen
                echo -n " ●$staged"
            end

            # Unstaged files (thinner plus)
            if test $unstaged -gt 0
                set_color bryellow
                echo -n " +$unstaged"
            end

            # Untracked files
            if test $untracked -gt 0
                set_color brwhite
                echo -n " …$untracked"
            end

            # Close branch block
            set_color brmagenta
            echo -n ")"

            set_color normal
        end
    end

    echo

    # =========================================
    # BLOCK 4: SECOND LINE - PROMPT CHARACTER
    # =========================================
    if fish_is_root_user
        set_color red
        echo -n "#"
    else
        set_color brblack
        echo -n '$'
    end
    set_color normal
    echo " "
end
