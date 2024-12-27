#!/bin/bash
queue="repl/karazawa"
echo "Monitoring $queue"
mosquitto_sub  -h "w2.inovacaosistemas.com.br" -t $queue -u "syspan" -P "3h9j1E34"
