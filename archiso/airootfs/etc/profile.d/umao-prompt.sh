# UmaOS terminal prompt
# Sky-blue brackets, pink $ sign
if [[ $TERM != "dumb" ]] && [[ -z "$INSIDE_EMACS" ]]; then
    PS1='\[\e[38;2;47;116;204m\][\[\e[0m\]uma\[\e[38;2;47;116;204m\]]\[\e[0m\] \u@\h \[\e[1m\]\w\[\e[0m\] \[\e[38;2;255;145;192m\]\$\[\e[0m\] '
fi
