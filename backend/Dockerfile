FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# Output to /out to avoid colliding with the ./aggregator source directory
# (go build -o <existing-dir> would write the binary *inside* that directory).
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/aggregator ./aggregator

FROM alpine:latest
WORKDIR /root/
COPY --from=builder /out/aggregator .
EXPOSE 8000
CMD ["./aggregator"]
