SRC_DIR="src"

while true
do
  clear
  date
  make
  inotifywait -r -e create,delete,move,close_write $SRC_DIR
done
