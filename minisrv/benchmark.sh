# classic threads
java -jar target/*jar &
PID=$!
ab -n 3000 -c 200 http://127.0.0.1:8080/io
ps -o rss= -p $PID          # prints RSS in KB
kill $PID

# virtual threads
java -Dvt=true -jar target/*jar &
PID=$!
ab -n 3000 -c 200 http://127.0.0.1:8080/io
ps -o rss= -p $PID
kill $PID