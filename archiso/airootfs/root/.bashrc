case "$-" in
  *i*)
    . /usr/local/bin/umao-show-ascii
    ;;
esac

# UmaOS themed prompt — green user@host, pink path (red for root)
PS1='\[\e[1;31m\]\u@\h\[\e[0m\] \[\e[1;35m\]\w\[\e[0m\] \$ '
