#!/bin/bash
queue="repl/karazawa"
iterations=${1:-1}  

words=()
while IFS= read -r line; do
    words+=("$line")
done < "latim-words.txt"

echo "Pinging $queue $iterations times"
for ((i=0; i<$iterations; i++)); do
    uuid=$(uuidgen)
    d=$(date)
    if [[ ${#words[@]} -gt 0 ]]; then        
        num_words=$((RANDOM % 9 + 2))
        shuffled_words=($(printf "%s\n" "${words[@]}" | sort -R))
        phrase=$(printf "%s " "${shuffled_words[@]:0:num_words}")
    else
        phrase="No words available"
    fi
    mosquitto_pub  -h "w2.inovacaosistemas.com.br" -t $queue -m "{\"sender\": \"pinger\", \"messageId\": \"$uuid\", \"subject\": \"test\", \"action\": \"ping\", \"target\": \"*\", \"payload\": {\"text\": \"$phrase\", \"data\": \"$d\"}}" -u "syspan" -P "3h9j1E34"
    echo "$d"
    if [[ $i -lt $((iterations-1)) ]]; then
        # sleep 3
    fi
done