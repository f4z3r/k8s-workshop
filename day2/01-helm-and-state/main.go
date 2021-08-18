package main

import (
    "fmt"
    "html"
    "log"
    "net/http"
    "github.com/go-redis/redis/v8"
    "context"
)


func main() {

    // TODO(@jakob): if using a single redis instance, use this client.
    // rdb := redis.NewClient(&redis.Options{
    //     Addr:     "example.com:1234", // TODO(@jakob): fill this address
    //     Password: "",
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
    })

    ctx := context.TODO()

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        key := html.EscapeString(r.URL.Path[1:])

        if r.Method == "GET" {
            val, err := rdb.Get(ctx, key).Result()
            switch {
            case err == redis.Nil:
                fmt.Fprintf(w, "key '%s' does not exist", key)
            case err != nil:
                fmt.Fprintf(w, "Get failed: %s", err)
            default:
                fmt.Fprintf(w, "%s=%s", key, val)
            }
        }

        if r.Method == "PUT" {
          fmt.Fprintf(w, "setting %s to value", key)
        }
    })

    // For liveness probe
    http.HandleFunc("/liveness", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "live!")
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
            fmt.Fprintf(w, "ready!")
        }
    })

    log.Fatal(http.ListenAndServe(":8080", nil))
}
