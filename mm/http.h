// https.h - HTTP/HTTPS client and redirector for J++
// Supports: URL generation, random tokens, redirects, snippets
// Author: Jatin (linuxab)

#ifndef HTTPS_PP_H
#define HTTPS_PP_H

#include <ios++>

// ============================================
// HTTP Methods
// ============================================

enum http_method {
    HTTP_GET,
    HTTP_POST,
    HTTP_PUT,
    HTTP_DELETE,
    HTTP_PATCH,
    HTTP_HEAD,
    HTTP_OPTIONS,
    HTTP_CONNECT,
    HTTP_TRACE
};

// ============================================
// HTTP Status Codes
// ============================================

#define HTTP_OK                     200
#define HTTP_CREATED                201
#define HTTP_ACCEPTED               202
#define HTTP_NO_CONTENT             204
#define HTTP_MOVED_PERMANENTLY      301
#define HTTP_FOUND                  302  // Redirect
#define HTTP_SEE_OTHER              303
#define HTTP_NOT_MODIFIED           304
#define HTTP_TEMPORARY_REDIRECT     307
#define HTTP_PERMANENT_REDIRECT     308
#define HTTP_BAD_REQUEST            400
#define HTTP_UNAUTHORIZED           401
#define HTTP_FORBIDDEN              403
#define HTTP_NOT_FOUND              404
#define HTTP_INTERNAL_ERROR         500
#define HTTP_BAD_GATEWAY            502
#define HTTP_SERVICE_UNAVAILABLE      503

// ============================================
// URL Components
// ============================================

struct url_parts {
    string protocol;    // "http" or "https"
    string domain;      // "www.example.com"
    int port;           // 80, 443, etc.
    string path;        // "/page/index.html"
    string query;       // "?id=123&name=test"
    string fragment;    // "#section1"
};

// ============================================
// Random Token Generator
// ============================================

// Generate random string like "19ec066-a1823-b9032-8000"
string token_gen(int segments, int chars_per_segment);

// Generate UUID v4 style: "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
string uuid_gen();

// Generate random hex string
string hex_gen(int length);

// Generate random alphanumeric
string rand_alnum(int length);

// Generate random with custom pattern: "%s%s-%d%s"
string rand_pattern(string pattern);

// ============================================
// Snippet System (HTTP code snippets)
// ============================================

// Snippet types for HTTP operations
enum snippet_type {
    SNIPPET_GET,           // HTTP GET request snippet
    SNIPPET_POST,          // HTTP POST request snippet
    SNIPPET_REDIRECT,      // Redirect handler snippet
    SNIPPET_COOKIE,        // Cookie handling snippet
    SNIPPET_HEADER,        // Header manipulation snippet
    SNIPPET_AUTH,          // Authentication snippet
    SNIPPET_PROXY,         // Proxy configuration snippet
    SNIPPET_SSL,           // SSL/TLS snippet
    SNIPPET_WEBSOCKET,     // WebSocket snippet
    SNIPPET_STREAM         // Streaming data snippet
};

// Insert HTTP snippet into code
void snippet(snippet_type type, string params);

// ============================================
// HTTP Socket (Client)
// ============================================

struct http_socket {
    // Connection
    void connect(string url);
    void connect(string domain, int port);
    void disconnect();
    bool is_connected();
    
    // Request methods
    void GET(string path);
    void POST(string path, string data);
    void PUT(string path, string data);
    void DELETE(string path);
    
    // URL with generated tokens
    void GET_token(string path_pattern, string token);
    void GET_rand(string path_pattern, int segments, int chars);
    
    // Redirect handling
    void follow_redirects(bool enable);
    int max_redirects(int count);
    string get_redirect_url();
    
    // Response
    int status_code();
    string status_text();
    string response_body();
    string response_headers();
    string header(string name);
    
    // URL manipulation
    void set_url(string url);
    string get_url();
    url_parts parse_url(string url);
    string build_url(url_parts parts);
    
    // Query parameters
    void add_param(string key, string value);
    void add_param(string key, int value);
    void add_param_rand(string key, int length);  // Add random value
    string build_query();
    
    // Cookies
    void set_cookie(string name, string value);
    string get_cookie(string name);
    
    // Headers
    void set_header(string name, string value);
    string get_header(string name);
    
    // SSL/TLS
    void verify_ssl(bool verify);
    void set_cert(string cert_path);
    
    // Proxy
    void set_proxy(string proxy_url);
    void set_proxy(string host, int port);
    
    // Timeout
    void set_timeout(int seconds);
    
    // User agent
    void set_user_agent(string ua);
};

// ============================================
// HTTPS Socket (Secure Client)
// ============================================

struct https_socket : http_socket {
    // HTTPS specific
    void set_tls_version(string version);  // "1.0", "1.1", "1.2", "1.3"
    void set_cipher_suites(string ciphers);
    void set_sni(string hostname);
    void set_alpn(string protocols);  // "h2,http/1.1"
    
    // Certificate pinning
    void pin_certificate(string fingerprint);
    void pin_public_key(string pubkey);
};

// ============================================
// Redirector
// ============================================

// Simple redirect to URL
void redirect(string url);

// Redirect with delay
void redirect_delay(string url, int seconds);

// Redirect with generated token in URL
void redirect_token(string base_url, string token_key, int token_length);

// Open browser/system default
void open_browser(string url);

// ============================================
// URL Shortener / Generator
// ============================================

// Generate random URL path: "/page/19ec066-a1823-b9032-8000"
string rand_url_path(string base_path, int segments, int chars);

// Generate tracking URL with random ID
string tracking_url(string base_url, string campaign);

// Generate one-time URL
string onetime_url(string base_url);

// ============================================
// HTTP Client Functions (Simple API)
// ============================================

// Quick GET request
string http_get(string url);

// Quick POST request
string http_post(string url, string data);

// Download to file
void http_download(string url, string filename);

// Check if URL is reachable
bool http_ping(string url);

// Get final URL after redirects
string http_resolve(string url);

// ============================================
// WebSocket Client
// ============================================

struct websocket_client {
    void connect(string url);           // "wss://echo.websocket.org"
    void send(string message);
    string receive();
    void close();
    bool is_open();
    
    // Events (callbacks)
    void on_open(void (*callback)());
    void on_message(void (*callback)(string msg));
    void on_close(void (*callback)(int code, string reason));
    void on_error(void (*callback)(string error));
};

// ============================================
// Streaming
// ============================================

struct http_stream {
    void open(string url);
    string read_chunk(int size);
    bool has_more();
    void close();
};

#endif // HTTPS_PP_H
'''

with open(f"{stdlib_dir}/https.h", "w") as f:
    f.write(https_h)

# ============================================
# EXAMPLE: HTTP Client with Token Generation
# ============================================

http_example = '''#include <https>
#include <ios++>

int main(){
    
    // ============================================
    // Basic HTTP GET with random token
    // ============================================
    
    // Generate random token: "19ec066-a1823-b9032-8000"
    string token = token_gen(4, 6);
    printel("Generated token: %s\\n", token);
    
    // Create HTTPS socket
    https_socket client;
    client.connect("www.example.com", 443);
    
    // GET request with generated token in URL
    // Your syntax: *(https(socket) client)
    //              =(socket) *(%client%)=[https] *($snippets%socket%URL$)
    
    // Clean J++ syntax:
    client.GET_token("/page/%s", token);
    
    // Or with random generation inline:
    client.GET_rand("/api/v1/%s/data", 3, 8);  // Generates "/api/v1/abc123de-xyz789ab-.../data"
    
    // Check response
    if (client.status_code() == HTTP_OK) {
        printel("Response: %s\\n", client.response_body());
    }
    
    client.disconnect();
    
    // ============================================
    // Redirect to website with generated URL
    // ============================================
    
    // Generate random URL path
    string rand_path = rand_url_path("/track", 3, 5);
    printel("Random path: %s\\n", rand_path);
    
    // Full URL with domain and random path
    string full_url = "https://www.web.domain" + rand_path + "/page/" + token + ".com";
    printel("Full URL: %s\\n", full_url);
    
    // Redirect user to this URL
    redirect(full_url);
    
    // Or with delay
    // redirect_delay(full_url, 5);  // Redirect after 5 seconds
    
    // Or open in browser
    // open_browser(full_url);
    
    // ============================================
    // Using snippets (HTTP code templates)
    // ============================================
    
    // Insert GET request snippet
    snippet(SNIPPET_GET, "url=https://api.example.com/data");
    
    // Insert redirect snippet
    snippet(SNIPPET_REDIRECT, "url=https://www.example.com, delay=3");
    
    // ============================================
    // Advanced: URL with multiple random params
    // ============================================
    
    http_socket api_client;
    api_client.connect("api.example.com", 443);
    
    // Add random query parameters
    api_client.add_param_rand("session_id", 16);   // ?session_id=a1b2c3d4e5f6...
    api_client.add_param_rand("token", 32);        // &token=xyz789...
    api_client.add_param("version", 1);            // &version=1
    
    // Build full URL with query
    string query_url = "https://api.example.com/auth" + api_client.build_query();
    printel("Query URL: %s\\n", query_url);
    
    api_client.GET("/auth");
    
    // ============================================
    // UUID generation example
    // ============================================
    
    string uuid = uuid_gen();
    printel("UUID: %s\\n", uuid);  // "550e8400-e29b-41d4-a716-446655440000"
    
    // Hex generation
    string hex = hex_gen(16);
    printel("Hex: %s\\n", hex);  // "a1b2c3d4e5f67890"
    
    // Alphanumeric
    string alnum = rand_alnum(20);
    printel("Alnum: %s\\n", alnum);  // "xK9mP2nQ5vB8wR4tY7"
    
    return 0:
}
'''

with open(f"{base}/examples/http_client.jpp", "w") as f:
    f.write(http_example)

# ============================================
# EXAMPLE: Your Original Syntax (Interpreted)
# ============================================

original_syntax = '''#include <https>
#include <ios++>

// This shows how your original syntax maps to clean J++

int main(){
    
    // Your original syntax:
    // main(void *http)= *(https(socket) client)
    // =(socket) *(%client%)=[https] *($snippets%socket%URL$)
    // void bss(.data(cons)=http://www.web.domain/page/%string%$_(num).com
    
    // Clean J++ equivalent:
    
    // 1. Create HTTPS socket client
    https_socket client;
    client.connect("www.web.domain", 443);
    
    // 2. Generate random string token (like "19ec066-a1823-b9032-8000")
    string token = token_gen(4, 6);  // 4 segments, 6 chars each
    
    // 3. Build URL with token: http://www.web.domain/page/TOKEN.com
    string url = "http://www.web.domain/page/" + token + ".com";
    
    // 4. Use snippet for HTTP socket operation
    snippet(SNIPPET_GET, "url=" + url);
    
    // 5. Store URL in data section (constant)
    const string stored_url = url;  // Stored in .data/.rodata section
    
    // 6. Redirect to the generated URL
    redirect(url);
    
    // Or with all your original syntax elements:
    
    // *(https(socket) client)  ->  https_socket client; client.connect(...)
    // =(socket) *(%client%)    ->  client.GET(...)
    // [https] *($snippets...)   ->  snippet(SNIPPET_GET, ...)
    // void bss(.data(cons)=...)  ->  const string ... = ...
    // %string%$_(num)          ->  token_gen(...)  or  rand_alnum(...)
    
    return 0:
}