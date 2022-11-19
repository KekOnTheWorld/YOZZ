const std = @import("std");
const net = std.net;
const fs = std.fs;

const Allocator = std.mem.Allocator;

// 

pub const HttpParseError = error {
    InvalidMethod, InvalidVersion, InvalidStatus
};

pub const Method = enum {
    GET, HEAD, POST, PUT,
    DELETE, CONNECT, OPTIONS, 
    TRACE, PATCH,

    pub fn parse(method: []u8) HttpParseError!Method {
        return std.meta.stringToEnum(Method, method) orelse HttpParseError.InvalidMethod;
    }
};

pub const Version = enum {
    @"HTTP/1.1", @"HTTP/1.2",

    pub fn parse(version: []u8) HttpParseError!Version {
        return std.meta.stringToEnum(Version, version) orelse HttpParseError.InvalidVersion;
    }

    pub fn toString(self: Version) [:0]const u8 {
        return switch(self) {
            Version.@"HTTP/1.1" => "HTTP/1.1",
            Version.@"HTTP/1.2" => "HTTP/1.2"
        };
    }
};

pub const Status = enum(u16) {
    // INFORMATION RESPONSES
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#information_responses
    CONTINUE = 100,
    SWITCHING_PROTOCOLS = 101,
    PROCESSING = 102,
    EARLY_HINTS = 103,

    // SUCCESSFUL RESPONSES
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#successful_responses
    OK = 200,
    CREATED = 201,
    ACCEPTED = 202,
    NON_AUTHORITATIVE_INFORMATION = 203,
    NO_CONTENT = 204,
    RESET_CONTENT = 205,
    PARTIAL_CONTENT = 206,
    MULTI_STATUS = 207,
    ALREADY_REPORTED = 208,
    IM_USED = 226,

    // REDIRECTION MESSAGES
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#redirection_messages
    MULTIPLE_CHOICES = 300,
    MOVED_PERMANENTLY = 301,
    FOUND = 302,
    SEE_OTHER = 303,
    NOT_MODIFIED = 304,
    // Use Proxy no longer of spec
    TEMPORARY_REDIRECT = 307,
    PERMANENT_REDIRECT = 308,

    // CLIENT ERROR RESPONSES
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#client_error_responses
    BAD_REQUEST = 400,
    UNAUTHORIZED = 401,
    PAYMENT_REQUIRED = 402,
    FORBIDDEN = 403,
    NOT_FOUND = 404,
    METHOD_NOT_ALLOWED = 405,
    NOT_ACCEPTABLE = 406,
    PROXY_AUTHENTICATION_REQUIRED = 407,
    REQUEST_TIMEOUT = 408,
    CONFLICT = 409,
    GONE = 410,
    LENGTH_REQUIRED = 411,
    PRECONDITION_FAILED = 412,
    PAYLOAD_TOO_LARGE = 413,
    URI_TOO_LONG = 414,
    UNSUPPORTED_MEDIA_TYPE = 415,
    RANGE_NOT_SATISFIABLE = 416,
    EXPECTATION_FAILED = 417,
    IM_A_TEAPOT = 418,
    MISDIRECTED_REQUEST = 421,
    UNPROCESSABLE_ENTRY = 422,
    LOCKED = 423,
    FAILED_DEPENDENCY = 424,
    TOO_EARLY = 425,
    UPGRADE_REQUIRED = 426,
    PRECONDITION_REQUIRED = 428,
    TOO_MANY_REQUESTS = 429,
    REQUEST_HEADER_FIELDS_TOO_LARGE = 431,
    UNAVALIDABLE_FOR_LEGAL_REASONS = 451,

    // SERVER ERROR RESPONSES
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#server_error_responses
    INTERNAL_SERVER_ERROR = 500,
    NOT_IMPLEMENTED = 501,
    BAD_GATEWAY = 502,
    SERVICE_UNAVAILABLE = 503,
    GATEWAY_TIMEOUT = 504,
    HTTP_VERSION_NOT_SUPPORTED = 505,
    VARIANT_ALSO_NEGOTIATES = 506,
    INSUFFICIENT_STORAGE = 507,
    LOOP_DETECTED = 508,
    NOT_EXTENDED = 510,
    NETWORK_AUTHENTICATION_REQUIRED = 511,

    pub fn parse(code: u16) HttpParseError!Status {
        return std.meta.intToEnum(Status, code) catch HttpParseError.InvalidStatus;
    }

    pub fn toString(self: Status) [:0]const u8 {
        return switch(self) {
            // INFORMATION RESPONSES
            Status.CONTINUE => "100 Continue",
            Status.SWITCHING_PROTOCOLS => "101 Switching Protocols",
            Status.PROCESSING => "102 Processing",
            Status.EARLY_HINTS => "103 EARLY_HINTS",

            // SUCCESSFUL RESPONSES
            Status.OK => "200 OK",
            Status.CREATED => "201 CREATED",
            Status.ACCEPTED => "202 ACCEPTED",
            Status.NON_AUTHORITATIVE_INFORMATION => "203 Non-Authoritative Information",
            Status.NO_CONTENT => "204 No Content",
            Status.RESET_CONTENT => "205 Reset Content",
            Status.PARTIAL_CONTENT => "206 Partial Content",
            Status.MULTI_STATUS => "207 Multi-Status",
            Status.ALREADY_REPORTED => "208 Already Reported",
            Status.IM_USED => "226 IM Used",
            
            // REDIRECTION MESSAGES
            Status.MULTIPLE_CHOICES => "300 Multiple Choices",
            Status.MOVED_PERMANENTLY => "301 Moved Permanently",
            Status.FOUND => "302 Found",
            Status.SEE_OTHER => "303 See Other",
            Status.NOT_MODIFIED => "304 Not Modified",
            Status.TEMPORARY_REDIRECT => "307 Temporary Redirect",
            Status.PERMANENT_REDIRECT => "308 Permanent Redirect",

            // CLIENT ERROR RESPONSES
            Status.BAD_REQUEST => "400 Bad Request",
            Status.UNAUTHORIZED => "401 Unauthorized",
            Status.PAYMENT_REQUIRED => "402 Payment Required",
            Status.FORBIDDEN => "403 Forbidden",
            Status.NOT_FOUND => "404 Not Found",
            Status.METHOD_NOT_ALLOWED => "405 Method Not Allowed",
            Status.NOT_ACCEPTABLE => "406 Not Acceptable",
            Status.PROXY_AUTHENTICATION_REQUIRED => "407 Proxy Authentication Required",
            Status.REQUEST_TIMEOUT => "408 Request Timeout",
            Status.CONFLICT => "409 Conflict",
            Status.GONE => "410 Gone",
            Status.LENGTH_REQUIRED => "411 Length Required",
            Status.PRECONDITION_FAILED => "412 Precondition Failed",
            Status.PAYLOAD_TOO_LARGE => "413 Payload Too Large",
            Status.URI_TOO_LONG => "414 URI Too Long",
            Status.UNSUPPORTED_MEDIA_TYPE => "415 Unsupported Media Type",
            Status.RANGE_NOT_SATISFIABLE => "416 Range Not Satisfiable",
            Status.EXPECTATION_FAILED => "417 Expectation Failed",
            Status.IM_A_TEAPOT => "418 I'm a teapot",
            Status.MISDIRECTED_REQUEST => "421 Misdirected Request",
            Status.UNPROCESSABLE_ENTRY => "422 Unprocessable Entity",
            Status.LOCKED => "423 Locked",
            Status.FAILED_DEPENDENCY => "424 Failed Dependency",
            Status.TOO_EARLY => "425 Too Early",
            Status.UPGRADE_REQUIRED => "426 Upgrade Required",
            Status.PRECONDITION_REQUIRED => "428 Precondition Required",
            Status.TOO_MANY_REQUESTS => "429 Too Many Requests",
            Status.REQUEST_HEADER_FIELDS_TOO_LARGE => "431 Request Header Files Too Large",
            Status.UNAVALIDABLE_FOR_LEGAL_REASONS => "451 Unavailable For Legal Reasons",

            // SERVER ERROR RESPONSES
            Status.INTERNAL_SERVER_ERROR => "500 Internal Server Error",
            Status.NOT_IMPLEMENTED => "501 Not Implemented",
            Status.BAD_GATEWAY => "502 Bad Gateway",
            Status.SERVICE_UNAVAILABLE => "503 Service Unavailable",
            Status.GATEWAY_TIMEOUT => "504 Gateway Timeout",
            Status.HTTP_VERSION_NOT_SUPPORTED => "505 HTTP Version Not Supported",
            Status.VARIANT_ALSO_NEGOTIATES => "506 Variant Also Negotiates",
            Status.INSUFFICIENT_STORAGE => "507 Insufficient Storage",
            Status.LOOP_DETECTED => "508 Loop Detected",
            Status.NOT_EXTENDED => "510 Not Extended",
            Status.NETWORK_AUTHENTICATION_REQUIRED => "511 Network Authentification Required",
        };
    }
};

pub const Header = struct {
    name: []const u8, value: []const u8,

    pub fn parse(name: []const u8, value: []const u8) HttpParseError!Header {
        return Header {
            .name = name, .value = value
        };
    }
};

pub const Path = []u8;

pub fn parsePath(path: []u8) HttpParseError!Path {
    return path;
}

// 

pub const HTTPContext = struct {
    stream: net.Stream,
    allocator: Allocator,

    pub fn init(allocator: Allocator, stream: net.Stream) HTTPContext {
        return HTTPContext {
            .stream = stream,  
            .allocator = allocator,
        };
    }

    pub fn deinit(_: *HTTPContext) void {}
};

// 

pub fn listen(addr: net.Address, allocator: Allocator) !void {
    // Open the static file directory
    var listener = net.StreamServer.init(.{});

    defer listener.deinit();

    try listener.listen(addr);

    std.log.debug("Listening on http://{}", .{addr});

    var parser = try Parser(HTTPContext).init(allocator, 256);
    defer parser.deinit();

    while(listener.accept() catch null) |conn| {
        parser.reset();
        
        const stream: net.Stream = conn.stream;

        // Make sure the stream gets closed properly after request is handeled
        defer {
            std.log.debug("End connection from {}", .{conn.address});
            stream.close();
        }

        std.log.debug("Connection from {}", .{conn.address});

        std.log.debug("---------------------", .{});

        var ctx = HTTPContext.init(allocator, stream);
        defer ctx.deinit();

        var recv_buf: [64]u8 = undefined;
        while(stream.read(&recv_buf) catch null) |recv_len| {
            if(recv_len == 0) break; // EOF

            try parser.write(recv_buf[0..recv_len], &ctx);

            if(parser.state == ParseState.FINISHED) break;
        }

        std.log.debug("---------------------", .{});
    }
}

// 
// HTTP Parser
// 

const StackBuf = @import("../util/stack.zig").StackBuf;

pub const ParseState = enum {
    METHOD, PATH, VERSION, HEADER_NAME, HEADER_VALUE, FINISHED
};

pub fn Parser(
    comptime Context: type
) type {
    return struct {
        // Default handlers
        pub fn onMethod(_: *Context, _: Method) anyerror!void {}
        pub fn onPath(_: *Context, _: Path) anyerror!void {}
        pub fn onVersion(_: *Context, _: Version) anyerror!void {}
        pub fn onHeader(_: *Context, _: Header) anyerror!void {}
        pub fn onEnd(_: *Context) anyerror!void {}

        header: usize,
        state: ParseState,
        stack: StackBuf,

        on_method: *const @TypeOf(onMethod) = onMethod,
        on_path: *const @TypeOf(onPath) = onPath,
        on_version: *const @TypeOf(onVersion) = onVersion,
        on_header: *const @TypeOf(onHeader) = onHeader,
        on_end: *const @TypeOf(onEnd) = onEnd,

        const Self = @This();

        // Initialize the Parser. This will
        // allocate a new Stack with size of cap
        pub fn init(allocator: Allocator, stack_cap: usize) !Self {
            return Self {
                .header = 0,
                .state = @intToEnum(ParseState, 0),
                .stack = try StackBuf.init(allocator, stack_cap)
            };
        }

        // Deinitialize the Parser. This will deinitialize
        // its stack and its request object.
        pub fn deinit(self: *Self) void {
            self.stack.deinit();
        }

        // Reset the Parser to its initial State
        pub fn reset(self: *Self) void {
            self.state = @intToEnum(ParseState, 0);
            self.stack.reset();
            self.header = 0;
        }

        // Handle multiple bytes
        pub fn write(self: *Self, data: []u8, ctx: *Context) !void {
            for(data) |byte| try self.handle(byte, ctx);
        }

        // Handle byte
        pub fn handle(self: *Self, byte: u8, ctx: *Context) !void {
            return switch(self.state) {
                ParseState.METHOD => {
                    if(byte != ' ') return self.append(byte);

                    const method = try Method.parse(self.stack.slice());

                    std.log.debug("METHOD: {}", .{method});

                    try self.on_method(ctx, method);

                    self.stack.reset();
                    self.state = ParseState.PATH;
                },
                ParseState.PATH => {
                    if(byte != ' ') return self.append(byte);

                    const path = try parsePath(self.stack.slice());

                    std.log.debug("PATH: {s}", .{path});

                    try self.on_path(ctx, path);

                    self.stack.reset();
                    self.state = ParseState.VERSION;
                },
                ParseState.VERSION => {
                    if(byte != '\n') return self.append(byte);

                    const version = try Version.parse(self.stack.slice());

                    std.log.debug("VERSION: {}", .{version});

                    try self.on_version(ctx, version);

                    self.stack.reset();
                    self.state = ParseState.HEADER_NAME;
                },
                ParseState.HEADER_NAME => {
                    if(byte == '\n') {
                        self.state = ParseState.FINISHED;

                        std.log.debug("END OF MESSAGE", .{});

                        return try self.on_end(ctx);
                    }

                    if(byte != ' ') return self.append(byte);

                    // Pop the ':' from the stack
                    self.stack.pop();

                    // Store the split position between header name and value
                    self.header = self.stack.len;

                    self.state = ParseState.HEADER_VALUE;
                },
                ParseState.HEADER_VALUE => {
                    if(byte != '\n') return self.append(byte);

                    const name = self.stack.buf[0..self.header];
                    const value = self.stack.buf[self.header..self.stack.len];

                    const header = try Header.parse(name, value);

                    std.log.debug("HEADER: {s}: {s}", .{header.name, header.value});

                    try self.on_header(ctx, header);

                    self.stack.reset();
                    self.state = ParseState.HEADER_NAME;
                },
                ParseState.FINISHED => {}
            };
        }

        // Append byte to stack
        pub fn append(self: *Self, byte: u8) void {
            if(byte == '\r' or byte == '\n') return;
            self.stack.push(byte);
        }
    };
}