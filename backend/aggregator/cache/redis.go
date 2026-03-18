package cache

import (
	"context"
	"time"
	"github.com/go-redis/redis/v8"
)

type Cache struct {
	Client *redis.Client
}

func NewCache(addr string) *Cache {
	rdb := redis.NewClient(&redis.Options{
		Addr: addr,
	})
	return &Cache{Client: rdb}
}

func (c *Cache) Get(ctx context.Context, key string) (string, error) {
	return c.Client.Get(ctx, key).Result()
}

func (c *Cache) Set(ctx context.Context, key string, value string, expiration time.Duration) error {
	return c.Client.Set(ctx, key, value, expiration).Err()
}
