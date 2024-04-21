FROM golang:alpine AS builder

# Set necessary environmet variables needed for our image
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# Move to working directory /build
WORKDIR /build

# Copy and download dependency using go mod
COPY go.mod .
COPY go.sum .
RUN go mod download

# Copy the code into the container
COPY main.go .

# Build the application
RUN go build -tags=jsoniter -o main .

# Move to /dist directory as the place for resulting binary folder
WORKDIR /dist

# Copy binary from build to main folder
RUN cp /build/main .

# Build a small image
FROM scratch AS production

COPY --from=builder /dist/main /
COPY ./templates /templates
COPY ./LICENSE /LICENSE

# Fixes cert issue when calling Maxmind API
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ADD assests /assests

EXPOSE 8080

# Command to run
ENTRYPOINT ["/main"]

