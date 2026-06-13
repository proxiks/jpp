'''

with open('/mnt/agents/output/ci.yml', 'w') as f:
    f.write(ci_yml)

print(f"ci.yml created: {len(ci_yml)} chars")

# Create Dockerfile
_dockerfile = r'''# J++ Compiler Docker Image
FROM golang:1.21-alpine AS builder

WORKDIR /build
COPY . .
RUN go build -ldflags="-s -w" -o jpp ./cmd/jpp

# Runtime image
FROM alpine:latest
RUN apk add --no-cache nasm binutils gcc

COPY --from=builder /build/jpp /usr/local/bin/jpp
COPY --from=builder /build/boot.asm /usr/share/jpp/boot.asm
COPY --from=builder /build/kernel++.h /usr/share/jpp/kernel++.h
COPY --from=builder /build/x86_64++.h /usr/share/jpp/x86_64++.h

WORKDIR /workspace
ENTRYPOINT ["jpp"]
CMD ["--help"]
