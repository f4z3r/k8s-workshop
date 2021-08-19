package main

import (
    "fmt"
    "html"
    "log"
    "time"
    "io/ioutil"
    "net/http"
    "github.com/go-redis/redis/v8"
    "context"
)


func main() {

    // TODO(@jakob): if using a single redis instance, use this client.
    // rdb := redis.NewClient(&redis.Options{
    //     Addr:     "example.com:1234", // TODO(@jakob): fill this address
    //     Password: "",  // TODO(@jakob): enter the password required to connect
    //     DB:       0,
    // })


    // TODO(@jakob): comment out if you are not using a cluster
    rdb := redis.NewClusterClient(&redis.ClusterOptions{
        Addrs: []string{
            // TODO(@jakob): fix the following addresses
            "1.example.com:7000",
            "2.example.com:7000",
            "3.example.com:7000",
            "4.example.com:7000",
            "5.example.com:7000",
            "6.example.com:7000",
        },
        // TODO(@jakob): enter the password required to connect
        Password: "example-secret",
    })

    ctx := context.TODO()

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        key := html.EscapeString(r.URL.Path[1:])

        if r.Method == "GET" {
            val, err := rdb.Get(ctx, key).Result()
            switch {
            case err == redis.Nil:
                fmt.Fprintf(w, "key '%s' does not exist\n", key)
            case err != nil:
                fmt.Fprintf(w, "Get failed: %s\n", err)
            default:
                fmt.Fprintf(w, "%s=%s\n", key, val)
            }
        }

        if r.Method == "PUT" {
            data, err := ioutil.ReadAll(r.Body)
            if err != nil {
                http.Error(w, "failed to get request data!", 500) 
            }
            value := string(data)
            err = rdb.Set(ctx, key, value, time.Duration(48*time.Hour)).Err()
            if err != nil {
                fmt.Fprintf(w, "Set failed: %s\n", err)
            } else {
                fmt.Fprintf(w, "set %s to value %s\n", key, value)
            }
        }
    })

    // For liveness probe
    http.HandleFunc("/liveness", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprint(w, "live!\n")
    })

    // For readiness probe
    http.HandleFunc("/readiness", func(w http.ResponseWriter, r *http.Request) {
        // TODO(@jakob): if using a single instance, uncomment the following line
        // err := rdb.Ping(ctx).Err()
        // TODO(@jakob): if using a single instance, comment the following 3 lines
        err := rdb.ForEachShard(ctx, func(ctx context.Context, shard *redis.Client) error {
            return shard.Ping(ctx).Err()
        })

        if err != nil {
           http.Error(w, "not ready yet!", 500) 
        } else {
            fmt.Fprint(w, "ready!\n")
        }
    })

    log.Fatal(http.ListenAndServe(":8080", nil))
}
