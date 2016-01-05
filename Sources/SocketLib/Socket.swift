//
//  Socket.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 10/12/2015.
//  Copyright © 2015 Andrew Thompson. All rights reserved.
//

import Foundation

/// The `type` of socket, which specifies the semantics of communication.
public enum SocketType {
    /// Sends packets reliably, and ensuring they arrive in the same order as
    /// they were sent in.
    case Stream
    /// Sends packets unreliably and quickly, not guarenteeing the arival or
    /// the arival order.
    case Datagram
    /// Provides access to the raw communication model. This is restricted to
    /// the super-user.
    case Raw
    
    /// Returns the integer associated with `self` for use with the networking
    /// calls.
    var systemValue: Int32 {
        switch self {
        case .Stream:
            return SOCK_STREAM
        case .Datagram:
            return SOCK_DGRAM
        case .Raw:
            return SOCK_RAW
        }
    }
}

/// The currently understood communication domains within which communication
/// will take place. These parameters are defined in <sys/socket.h>
public enum DomainAddressFamily {
    /// Host-internal protocols, formerly UNIX
    case Local
    /// Host-internal protocls, deprecated, use Local
    @available(OSX, deprecated=10.11, renamed="Local")
    case UNIX
    /// Internet version 4 protocols
    case INET
    /// Internal Rounting protocols
    case Route
    /// Internal key-management function
    case Key
    /// Internet version 6 protocol
    case INET6
    /// System domain
    case System
    /// Raw access to network device
    case NDRV
    
    /// Returns the integer associated with `self` for use with the networking
    /// calls.
    var systemValue: Int32 {
        switch self {
        case .Local:
            return PF_LOCAL
        case .UNIX:
            return PF_UNIX
        case .INET:
            return PF_INET
        case .Route:
            return PF_ROUTE
        case .Key:
            return PF_KEY
        case .INET6:
            return PF_INET6
        case .System:
            return PF_SYSTEM
        case .NDRV:
            return PF_NDRV
        }
    }
}

/// The specific protocol methods used for transfering data. The very common
/// protocols are listed below. For all the protocols, see /etc/protocols and 
/// <inet/in.h>.
public enum CommunicationProtocol {
    /// Transmission Control Protocol
    case TCP
    /// User Datagram Protocol
    case UDP
    /// Raw Protocol
    case RAW
    /// Used to specify another protocol to use.
    case Other(Int32)
    
    /// Returns the integer associated with `self` for use with the networking
    /// calls.
    var systemValue: Int32 {
        switch self {
        case .TCP:
            return IPPROTO_TCP
        case .UDP:
            return IPPROTO_UDP
        case .RAW:
            return IPPROTO_RAW
        case .Other(let n):
            return n
        }
    } 
}

public enum SocketError : ErrorType {
    /// Thrown when a call to `Darwin.socket()` fails. The associate value holds
    /// the error number returned.
    case CreationFailed(Int32)
    /// Thrown when a call to `Darwin.close()` fails. The associate value holds
    /// the error number returned.
    case CloseFailed(Int32)
    /// Thrown when an invalid parameter is detected. The associate value holds
    /// a description of the error. This is considered a programming error.
    case ParameterError(String)
    /// Thrown by `bind()` or `connect()` when all possible addresses with the
    /// given information have been exhausted. The associate string holds a
    /// description of the error, and the array holds errors returned from the
    /// system call.
    @available(OSX, deprecated=10.10, renamed="NoAddressesAvailable")
    case NoAddressesFound(String, [Int32])
    /// Thrown by `bind()` or `connect()` when all possible addresses with the
    /// given information has been exhausted. The associate array holds the
    /// errors returned from the system call.
    case NoAddressesAvailable([Int32])
    /// Thrown when binding to a `Local` (aka `Unix`) file address. The 
    /// associate value holds the error number returned from `Darwin.unlink()`.
    case UnlinkFailed(Int32)
    /// Thrown when a call to `Darwin.bind()` fails. The associate value holds
    /// the error number returned.
    case BindFailed(Int32)
    /// Thrown when a call to `Darwin.connect()` fails. The associate value
    /// holds the error number returned.
    case ConnectFailed(Int32)
    /// Thrown when a call to `Darwin.sendto()` fails. The associate value holds
    /// the error number returned.
    case SendToFailed(Int32)
    /// Thrown when a call to `Darwin.sendmsg()` fails. The associate value
    /// holds the error number returned.
    case SendMSGFailed(Int32)
    /// Thrown when no data is available on a non-blocking socket. A subsequent
    /// call may yield data.
    case RecvTryAgain
    /// Thrown when a call to `Darwin.recvfrom()` fails. The associate value
    /// holds the error number returned.
    case RecvFromFailed(Int32)
    /// Thrown when a call to `Darwin.accept()` fails. The associate value holds
    /// the error number returned.
    case AcceptFailed(Int32)
    /// Thrown when a call to `Darwin.listen()` fails. The associate value holds
    /// the error number returned.
    case ListenFailed(Int32)
    /// Thrown when a call to `Darwin.setsockopt()` fails. The associate value
    /// holds the error number returned.
    case SetSocketOptionFailed(Int32)
    /// Thrown when a call to `Darwin.shutdown()` fails. The associate value
    /// holds the error number returned.
    case ShutdownFailed(Int32)
}
/// A class for manipulating sockets, similar to the python module socket.
/// What else is there to say, their sockets...
public class Socket {
    
    public          var fd      : Int32
    public          var address : AddrInfo
    private(set)    lazy var peerAddress: AddrInfo? = {
        [unowned self] in
        
        let sock_storage = UnsafeMutablePointer<sockaddr_storage>.alloc(sizeof(sockaddr_storage))
        let sockaddr: UnsafeMutablePointer<Darwin.sockaddr> = UnsafeMutablePointer(sock_storage)
        var length = socklen_t(sizeof(sockaddr_storage))
        // Get the peer information.
        guard getpeername(self.fd, sockaddr, &length) == 0 else {
            sock_storage.dealloc(sizeof(sockaddr_storage))
            return nil // I would like to throw something here...
        }
        
        let addr = AddrInfo(copy: self.address.addrinfo)
        addr.sockaddr_storage.dealloc(sizeof(sockaddr_storage))
        addr.sockaddr_storage = sock_storage
        
        return addr
    }()
    private(set)    var closed  : Bool
    public          var shouldReuseAddress: Bool = true {
        didSet {
            do {
                try setShouldReuseAddress(shouldReuseAddress)
            } catch {} // Any way to get around this?
        }
    }
    /// Constructs an instance from a pre-exsisting file descriptor and address.
    /// - Throws:
    ///     - `SocketError.SetSocketOptionFailed`
    public init(socket: Int32, address addr: addrinfo,
                shouldReuseAddress: Bool = true) throws {
                    fd = socket
                    address = AddrInfo(copy: addr)
                    closed = false
                    self.shouldReuseAddress = shouldReuseAddress
                    try setShouldReuseAddress(shouldReuseAddress)
    }
    /// Constructs a socket from the given requirements. 
    ///
    /// For a typical TCP socket, do:
    ///
    ///         init(domain: .INET, type: .Stream, proto: .TCP)
    ///
    /// For a UDP socket, do:
    ///
    ///         init(domain: .INET, type: .Datagram, proto: .UDP)
    ///
    /// - seealso: [The socket man page](x-man-page://2/socket)
    ///
    /// - Throws: 
    ///     - `SocketError.CreationFailed`
    ///     - `SocketError.SetSocketOptionFailed`
    public init(
        domain: DomainAddressFamily,
        type: SocketType,
        proto: CommunicationProtocol
        ) throws {
            fd = Darwin.socket(
                domain.systemValue,
                type.systemValue,
                proto.systemValue
            )
            address = AddrInfo()
            address.addrinfo.ai_family = domain.systemValue
            address.addrinfo.ai_socktype = type.systemValue
            address.addrinfo.ai_protocol = proto.systemValue
            closed = false
            guard fd != -1 else {
                throw SocketError.CreationFailed(errno)
            }
            try setShouldReuseAddress(true)
    }
    /// Copys `address` and initalises the socket from the `fd` given.
    /// - parameter address: The socket's address.
    /// - parameter fd:      A valid socket file descriptor.
    private init(copy address: AddrInfo, fd: Int32) {
        self.address = address
        self.closed = true
        self.fd = fd
    }
    /// Re-initalises the socket to a 'new' state, ready for a call to bind
    /// or connect.
    ///
    /// When an attempt to bind or connect the socket fails, the file 
    /// descriptor become unusable. This method overcomes that problem.
    ///
    /// - Throws:
    ///     - `SocketError.CreationFailed`
    ///     - `SocketError.CloseFailed`
    ///     - `SocketError.SetSocketOptionFailed`
    private func initaliseSocket() throws {
        if !closed {
            try close()
        }
        fd = Darwin.socket(
            address.addrinfo.ai_family,
            address.addrinfo.ai_socktype,
            address.addrinfo.ai_protocol
        )
        guard fd != -1 else {
            throw SocketError.CreationFailed(errno)
        }
        closed = false
        try setShouldReuseAddress(shouldReuseAddress)
    }
    public enum ShutdownMethod {
        case PreventRead
        case PreventWrite
        case PreventRW
        var systemValue: Int32 {
            switch self {
            case .PreventRead:
                return SHUT_RD
            case .PreventWrite:
                return SHUT_WR
            case .PreventRW:
                return SHUT_RDWR
            }
        }
    }
    /// Shuts down the socket, signaling that either all reading has finished,
    /// all writing has finished, or both reading and writing have finished.
    /// A socket is not allowed to write if it has shutdown writing, similarly,
    /// it is not allowed to read if it has shutdown reading.
    /// 
    /// - seealso:
    ///     - `close()`
    ///     - [The shutdown man page][1]
    ///     - This [article][2] provides a good explanation for when to use
    ///         [shutdown][1] and [close][3].
    ///  
    /// [1]: x-man-page://2/shutdown
    /// [2]: https://msdn.microsoft.com/en-us/library/ms738547(VS.85).aspx
    /// [3]: x-man-page://2/close
    ///
    /// - Throws: `SocketError.ShutdownFailed`
    public func shutdown(how: ShutdownMethod) throws {
        guard Darwin.shutdown(
            fd,
            how.systemValue
            ) == 0 else {
                throw SocketError.ShutdownFailed(errno)
        }
    }
    /// Closes the socket.
    ///
    ///
    /// Closing the socket deletes any associated information with the socket.
    /// Thus, once a socket is closed, it is considered an error to perform any
    /// more operations on it.
    ///
    ///
    /// - Throws: `SocketError.CloseFailed`
    /// - seealso: 
    ///     - `shutdown(_)`
    ///     - [The close manual page][1]
    ///     - This [article][2] provides a good explanation for when to use
    ///         [close][1] and [shutdown][3].
    ///
    /// [1]: x-man-page://2/close
    /// [2]: https://msdn.microsoft.com/en-us/library/ms738547(VS.85).aspx
    /// [3]: x-man-page://2/shutdown
    public func close() throws {
        guard Darwin.close(
            fd
            ) == 0 else {
                throw SocketError.CloseFailed(errno)
        }
        closed = true
    }
    
    deinit {
        // Clean up what the user didn't
        if !closed {
            do { try close() } catch {}
        }
    }
}

extension Socket {

    // TODO: Write a better description
    // TODO: Test this function
    /// Binds the socket to the given address and port without performing any
    /// name resolution.
    ///
    /// - parameter address:    An address to bind to. The `address.addrinfo`
    ///                         must contain a valid ai_addr address, and
    ///                         ai_addrlen must be filled to be the size of the
    ///                         structure.
    /// - parameter port:       A non-negative integer describing the port to
    ///                         bind `self` to. Some values are reseverd for the
    ///                         system and require root privileges.
    /// - Throws:
    ///     - `SocketError.ParameterError`
    ///     - `SocketError.BindFailed`
    /// - Seealso:
    ///     - [The bind man page](x-man-page://2/bind)
    ///     - [Commonly known ports](https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers)
    public func bind(toAddress address: AddrInfo, port: Int32) throws {
        guard port >= 0 else {
            throw SocketError.ParameterError("Invalid port number - port cannot"
                + " be negative")
        }
        try address.setPort(port)
        guard Darwin.bind(fd,
            address.addrinfo.ai_addr,
            address.addrinfo.ai_addrlen
            ) == 0 else {
                throw SocketError.BindFailed(errno)
        }
        self.address = address
    }
    /// Binds the socket to the given hostname and port, performing host name
    /// resolution.
    ///
    /// A successful call to bind will result in the socket being assigend an 
    /// address. This allows for a connection to be established and for
    /// communication to commence.
    ///
    /// This function uses `getaddrinfo(hostname:service:hints:)` for obtaining
    /// an address, and passes a copy of `self.address` as the parameter for 
    /// hints. To pass any hints to `getaddrinfo(host:service:hints)`
    /// set them on `self.address`. Upon a successful call to bind,
    /// `self.address` will be updated with the new address assigned.
    ///
    /// - Remark:
    ///     Depending on the protocol, you must also call `listen(_:)` in order
    ///     to recieve incomming connections.
    ///
    /// - Seealso:
    ///     - [The bind man page][1]
    ///     - [Commonly known ports][2]
    ///
    /// [1]: x-man-page://2/bind
    /// [2]: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
    ///
    /// - parameter hostname:   A string which contains either a hostname or a 
    ///                         numeric ip address.
    /// - parameter port:       A non-negative integer to bind `self` to. Some
    ///                         values are reserved for the system and require
    ///                         root privileges.
    /// - Throws:
    ///     - `SocketError.ParameterError`
    ///     - `SocketError.NoAddressesAvailable`
    ///     - `SocketError.CreationFailed`
    ///     - `SocketError.CloseFailed`
    ///     - `SocketError.SetSocketOptionFailed`
    public func bind(toAddress hostname: String, port: Int32) throws {
        guard port >= 0 else {
            throw SocketError.ParameterError("Invalid port number - port cannot"
                + " be negative")
        }
        
        var hints = Darwin.addrinfo()
        hints.ai_socktype   = address.addrinfo.ai_socktype
        hints.ai_protocol   = address.addrinfo.ai_protocol
        hints.ai_family     = address.addrinfo.ai_family
        hints.ai_flags      = address.addrinfo.ai_flags
        
        var errors: [Int32] = []
        
        for host in try getaddrinfo(host: hostname,
                                        service: nil,
                                        hints: &hints)
        {
            try host.setPort(port)
            try initaliseSocket()
            
            guard Darwin.bind(
                fd,
                host.addrinfo.ai_addr,
                host.addrinfo.ai_addrlen
                ) == 0 else {
                    errors.append(errno)
                    try close()
                    continue
            }
            
            self.address = host
            return
        }
        throw SocketError.NoAddressesAvailable(errors)
    }
    /// Binds the socket to the given address on the file system. Use this for Local
    /// (aka Unix) socket connections.
    ///
    /// A successful call to bind will result in the socket being assigned an
    /// address which can be used for communications locally on the system.
    ///
    /// - parameter file:   An absolute path to a file. It does not need to
    ///                     exsist. The length of the string cannot be greater
    ///                     than 104 characters and must be encoded using
    ///                     NSUTF8StringEncoding.
    /// - parameter unlinkFile: `true` if the file should be removed, otherwise
    ///                         `false`. If the file exsists and
    ///                         `unlinkFile` is `false`, then the call to bind 
    ///                         will fail.
    /// - Seealso:
    ///     - `bind(toAddress:port:)`
    ///     - [The bind man pages](x-man-page://2/bind)
    /// - Throws:
    ///     - `SocketError.BindFailed`
    ///     - `SocketError.UnlinkFailed`
    public func bind(toFile file: String, shouldUnlink unlinkFile: Bool = true)
        throws {
            var addr_un = sockaddr_un()
            addr_un.sun_family = UInt8(address.addrinfo.ai_family)
            addr_un.setPath(file,
                length: file.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
            )
            
            UnsafeMutablePointer<sockaddr_un>(
                address.addrinfo.ai_addr
                ).memory = addr_un
            address.addrinfo.ai_addrlen = UInt32(sizeof(sockaddr_un))
            
            if unlinkFile {
                try unlink(file, errorOnFNF: false)
            }
            
            guard Darwin.bind(
                fd,
                address.addrinfo.ai_addr,
                address.addrinfo.ai_addrlen
                ) == 0
                else {
                    throw SocketError.BindFailed(errno)
            }
    }
    
    /// Unlinks the file at the given url.
    ///
    /// - parameter path:   The file to be removed.
    /// - parameter errorOnFNF: Setting this to `false` causes this function
    ///                         not to error when there is no file to unlink.
    private func unlink(path: String, errorOnFNF: Bool = true) throws {
        guard Darwin.unlink(
            path
            ) == 0 else {
                if !(!errorOnFNF && errno == ENOENT) {
                    throw SocketError.UnlinkFailed(errno)
                } else { return }
        }
    }
}
extension Socket {
    /// Connects the socket to the given hostname and port number.
    ///
    /// A successful call will result in the socket being associated with the
    /// hostname and port number. For connection orientated protocol (i.e. TCP),
    /// this yields the sockets in a connected state, ready for sending and
    /// recieving. For connectionless sockets, this allows the user to use
    /// `send(data:length:flags)`, thus removin the need for specifying an
    /// address every time.
    ///
    /// This function uses `getaddrinfo(hostname:service:hints:)` for obtaining
    /// an address, and passes a copy of `self.address` as the parameter for 
    /// hints. To pass any hints to `getaddrinfo(host:service:hints)`
    /// set them on `self.address`. Upon a successful call to connect, 
    /// `self.address` will be updated with the new address assigned.
    ///
    /// - Seealso:
    ///     - [The connect man page][1]
    ///     - [Commonly known ports][2]
    ///
    /// [1]: x-man-page://2/connect
    /// [2]: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
    ///
    /// - parameter hostname:   A string containing either a hostname or a
    ///                         numeric ip address.
    /// - parameter port:       A non-negative integer. Note that some ports
    ///                         require root privileges.
    /// - Throws:
    ///     - `SocketError.ParameterError`
    ///     - `SocketError.CreationFailed`
    ///     - `SocketError.CloseFailed`
    ///     - `SocketError.SetSocketOptionFailed`
    ///     - `SocketError.NoAddressesAvailable`
    public func connect(to hostname: String, port: Int32) throws {
        guard port >= 0 else {
            throw SocketError.ParameterError("Invalid port number - port cannot"
            + " be negative")
        }
        
        var hints = addrinfo()
        hints.ai_socktype   = address.addrinfo.ai_socktype
        hints.ai_protocol   = address.addrinfo.ai_protocol
        hints.ai_family     = address.addrinfo.ai_family
        hints.ai_flags      = address.addrinfo.ai_flags
        
        var errors: [Int32] = []
        
        for host in try getaddrinfo(host: hostname,
                                    service: nil,
                                    hints:  &hints)
        {
            try host.setPort(port)
            try initaliseSocket()
            
            guard Darwin.connect(
                fd,
                host.addrinfo.ai_addr,
                host.addrinfo.ai_addrlen
                ) == 0 else {
                    errors.append(errno)
                    try close()
                    continue
            }
            
            self.address = host
            return
        }
        throw SocketError.NoAddressesAvailable(errors)
    }
    /// Connects the socket to the given address and port number.
    /// 
    /// A successful call with result in teh socket being associated with the 
    /// address and port given.
    /// 
    /// For a full description, checkout `connect(toAddress:port:)`
    /// 
    /// - parameter address:    The address the socket will connect to.
    /// - parameter port:       A non-negative integer. Note that some ports
    ///                         require root privileges.
    ///
    /// - Throws:
    ///     - `SocketError.ParameterError`
    ///     - `SocketError.ConnectFailed`
    public func connect(to address: AddrInfo, port: Int32) throws {
        guard port >= 0 else {
            throw SocketError.ParameterError("Invalid port number - port cannot"
            + " be negative")
        }
        try address.setPort(port)
        address.addrinfo.ai_addrlen = UInt32(sizeofValue(address.addrinfo.ai_addr.memory))
        guard Darwin.connect(fd, address.addrinfo.ai_addr, address.addrinfo.ai_addrlen) == 0
            else {
                throw SocketError.ConnectFailed(errno)
        }
        self.address = address
    }
}
extension Socket {
    public func send(data: UnsafePointer<Void>, length: Int, flags: Int32 = 0,
        maxSize: Int = 1024) throws -> Int {
			var d = data 
            var bytesLeft = length
            var bytesSent = 0
            
            loop: while (length > bytesSent) {
                let len = bytesLeft < maxSize ? bytesLeft : maxSize
                let success = Darwin.sendto(fd, d, len, flags, nil, 0)
                guard success != -1 else {
                    throw SocketError.SendToFailed(errno)
                }
                d = d.advancedBy(success)
                bytesSent += success
                bytesLeft -= success
            }
            return bytesSent
    }
    public func send(to addr: AddrInfo, data: UnsafePointer<Void>,
        length: Int, flags: Int32 = 0, maxSize: Int = 1024) throws -> Int {
			var d = data 
            var bytesleft = length
            var bytesSent = 0
            
            loop: while (length > bytesSent) {
                let len = bytesleft < maxSize ? bytesleft : maxSize
                let success = Darwin.sendto(
                    fd, d, len, flags, addr.addrinfo.ai_addr,
                    UInt32(addr.addrinfo.ai_addr.memory.sa_len)
                )
                guard success != -1 else {
                    throw SocketError.SendToFailed(errno)
                }
                d = d.advancedBy(success)
                bytesSent += success
                bytesleft -= success
            }
            return bytesSent
    }
    public func send(inout msg: msghdr, flags: Int32 = 0, maxSize: Int = 1024)
        throws -> Int {
        
            // FIXME: Send message must be in a while loop
            // This function must keep sending data until either an error
            // occurred or all data has been sent.
            
            let isSuccess = Darwin.sendmsg(fd, &msg, flags)
            guard isSuccess != -1 else {
                throw SocketError.SendMSGFailed(errno)
            }
            return isSuccess
    }
    public func send(str: String, flags: Int32 = 0, maxSize: Int = 1024) throws {
        try self.send(str, length: str.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), flags: flags, maxSize: maxSize)
    }
    /// Make sure that data is already base 64 encoded, this just uses data.bytes
    /// and data.length (whene data is NSData).
    public func send(data: NSData, flags: Int32 = 0, maxSize: Int = 1024) throws {
        try self.send(data.bytes, length: data.length, flags: flags, maxSize: maxSize)
    }
}
extension Socket {
    public class Message {
        private(set) var data: UnsafeMutablePointer<Void>
        private(set) var length: Int
        private(set) var sender: sockaddr?
        
        init(claim data: UnsafeMutablePointer<Void>, length: Int,
            sender: sockaddr?) {
                self.data = data
                self.length = length
                self.sender = sender
        }
        init(copy data: UnsafeMutablePointer<Void>, length: Int,
            sender: sockaddr?) {
                self.data = UnsafeMutablePointer<Void>.alloc(length)
                self.length = length
                self.sender = sender
                memcpy(self.data, data, length)
        }
        deinit {
            data.dealloc(length)
        }
    }
    public func recv(maxSize: Int, flags: Int32 = 0) throws -> Message? {
        var buffer = UnsafeMutablePointer<Void>.alloc(maxSize + 1)
        var addrLen = socklen_t(sizeof(sockaddr))
        let addr = UnsafeMutablePointer<sockaddr>.alloc(sizeof(sockaddr))
        
        defer {
            buffer.dealloc(maxSize + 1)
            addr.dealloc(sizeof(sockaddr))
        }
        
        let success = Darwin.recvfrom(
            fd, buffer, maxSize, flags, addr, &addrLen
        )
        guard success != -1 else {
            switch errno {
            case EAGAIN:
                throw SocketError.RecvTryAgain
            default:
                throw SocketError.RecvFromFailed(errno)
            }
        }
        
        if success == 0 && self.address.addrinfo.ai_protocol == IPPROTO_TCP {
            return nil // Connection is closed if TCP and success == 0.
        }
        buffer[success] = ()
        return Message(copy: buffer, length: success + 1, sender: addr.memory)
    }
    // TODO: Add a recv(msg: etc...) function.
}
extension Socket {
    public func accept() throws -> Socket {
        let sockStorage = UnsafeMutablePointer<sockaddr_storage>.alloc(sizeof(sockaddr_storage))
        let sockaddr = UnsafeMutablePointer<Darwin.sockaddr>(sockStorage)
        var length = socklen_t(sizeof(sockaddr_storage))
        
        let success = Darwin.accept(fd, sockaddr, &length)
        guard success != -1 else {
            throw SocketError.AcceptFailed(errno)
        }
        
        let socket = Socket(copy: AddrInfo(copy: self.address.addrinfo), fd: success)
        socket.address.sockaddr_storage.dealloc(sizeof(sockaddr_storage))
        socket.address.sockaddr_storage = sockStorage // Substitute sockStorage
        
        return socket
    }
    public func listen(backlog: Int32) throws {
        guard backlog >= 0 else {
            throw SocketError.ParameterError("Backlog cannot be less than zero.")
        }
        guard Darwin.listen(fd, backlog) == 0 else {
            throw SocketError.ListenFailed(errno)
        }
    }
}
extension Socket {
    public func setShouldReuseAddress(value: Bool) throws {
        var number: CInt = value ? 1 : 0
        guard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &number, socklen_t(sizeof(CInt))) != -1 else {
            throw SocketError.SetSocketOptionFailed(errno)
        }
    }
}

extension sockaddr_un {
    /// - Warning: An data over the 104th index (index 103) is not copied into 
    ///             buffer.
    mutating func setPath(path: UnsafePointer<Int8>, length: Int) {
        
        var array = [Int8](count: 104, repeatedValue: 0)
        for i in 0..<length {
            array[i] = path[i]
        }
        setPath(array)
    }
    /// - Warning: Path must be at least 104 in length.
    mutating func setPath(path: [Int8]) {
        
        precondition(path.count >= 104, "Path must be at least 104 in length")
        
        sun_path.0 = path[0]
        // and so on for infinity ...
        // ... python is handy
        sun_path.1 = path[1]
        sun_path.2 = path[2]
        sun_path.3 = path[3]
        sun_path.4 = path[4]
        sun_path.5 = path[5]
        sun_path.6 = path[6]
        sun_path.7 = path[7]
        sun_path.8 = path[8]
        sun_path.9 = path[9]
        sun_path.10 = path[10]
        sun_path.11 = path[11]
        sun_path.12 = path[12]
        sun_path.13 = path[13]
        sun_path.14 = path[14]
        sun_path.15 = path[15]
        sun_path.16 = path[16]
        sun_path.17 = path[17]
        sun_path.18 = path[18]
        sun_path.19 = path[19]
        sun_path.20 = path[20]
        sun_path.21 = path[21]
        sun_path.22 = path[22]
        sun_path.23 = path[23]
        sun_path.24 = path[24]
        sun_path.25 = path[25]
        sun_path.26 = path[26]
        sun_path.27 = path[27]
        sun_path.28 = path[28]
        sun_path.29 = path[29]
        sun_path.30 = path[30]
        sun_path.31 = path[31]
        sun_path.32 = path[32]
        sun_path.33 = path[33]
        sun_path.34 = path[34]
        sun_path.35 = path[35]
        sun_path.36 = path[36]
        sun_path.37 = path[37]
        sun_path.38 = path[38]
        sun_path.39 = path[39]
        sun_path.40 = path[40]
        sun_path.41 = path[41]
        sun_path.42 = path[42]
        sun_path.43 = path[43]
        sun_path.44 = path[44]
        sun_path.45 = path[45]
        sun_path.46 = path[46]
        sun_path.47 = path[47]
        sun_path.48 = path[48]
        sun_path.49 = path[49]
        sun_path.50 = path[50]
        sun_path.51 = path[51]
        sun_path.52 = path[52]
        sun_path.53 = path[53]
        sun_path.54 = path[54]
        sun_path.55 = path[55]
        sun_path.56 = path[56]
        sun_path.57 = path[57]
        sun_path.58 = path[58]
        sun_path.59 = path[59]
        sun_path.60 = path[60]
        sun_path.61 = path[61]
        sun_path.62 = path[62]
        sun_path.63 = path[63]
        sun_path.64 = path[64]
        sun_path.65 = path[65]
        sun_path.66 = path[66]
        sun_path.67 = path[67]
        sun_path.68 = path[68]
        sun_path.69 = path[69]
        sun_path.70 = path[70]
        sun_path.71 = path[71]
        sun_path.72 = path[72]
        sun_path.73 = path[73]
        sun_path.74 = path[74]
        sun_path.75 = path[75]
        sun_path.76 = path[76]
        sun_path.77 = path[77]
        sun_path.78 = path[78]
        sun_path.79 = path[79]
        sun_path.80 = path[80]
        sun_path.81 = path[81]
        sun_path.82 = path[82]
        sun_path.83 = path[83]
        sun_path.84 = path[84]
        sun_path.85 = path[85]
        sun_path.86 = path[86]
        sun_path.87 = path[87]
        sun_path.88 = path[88]
        sun_path.89 = path[89]
        sun_path.90 = path[90]
        sun_path.91 = path[91]
        sun_path.92 = path[92]
        sun_path.93 = path[93]
        sun_path.94 = path[94]
        sun_path.95 = path[95]
        sun_path.96 = path[96]
        sun_path.97 = path[97]
        sun_path.98 = path[98]
        sun_path.99 = path[99]
        sun_path.100 = path[100]
        sun_path.101 = path[101]
        sun_path.102 = path[102]
        sun_path.103 = path[103]
        
    }
    func getPath() -> [Int8] {
        var path = [Int8](count: 104, repeatedValue: 0)
        
        path[0] = sun_path.0
        path[1] = sun_path.1
        path[2] = sun_path.2
        path[3] = sun_path.3
        path[4] = sun_path.4
        path[5] = sun_path.5
        path[6] = sun_path.6
        path[7] = sun_path.7
        path[8] = sun_path.8
        path[9] = sun_path.9
        path[10] = sun_path.10
        path[11] = sun_path.11
        path[12] = sun_path.12
        path[13] = sun_path.13
        path[14] = sun_path.14
        path[15] = sun_path.15
        path[16] = sun_path.16
        path[17] = sun_path.17
        path[18] = sun_path.18
        path[19] = sun_path.19
        path[20] = sun_path.20
        path[21] = sun_path.21
        path[22] = sun_path.22
        path[23] = sun_path.23
        path[24] = sun_path.24
        path[25] = sun_path.25
        path[26] = sun_path.26
        path[27] = sun_path.27
        path[28] = sun_path.28
        path[29] = sun_path.29
        path[30] = sun_path.30
        path[31] = sun_path.31
        path[32] = sun_path.32
        path[33] = sun_path.33
        path[34] = sun_path.34
        path[35] = sun_path.35
        path[36] = sun_path.36
        path[37] = sun_path.37
        path[38] = sun_path.38
        path[39] = sun_path.39
        path[40] = sun_path.40
        path[41] = sun_path.41
        path[42] = sun_path.42
        path[43] = sun_path.43
        path[44] = sun_path.44
        path[45] = sun_path.45
        path[46] = sun_path.46
        path[47] = sun_path.47
        path[48] = sun_path.48
        path[49] = sun_path.49
        path[50] = sun_path.50
        path[51] = sun_path.51
        path[52] = sun_path.52
        path[53] = sun_path.53
        path[54] = sun_path.54
        path[55] = sun_path.55
        path[56] = sun_path.56
        path[57] = sun_path.57
        path[58] = sun_path.58
        path[59] = sun_path.59
        path[60] = sun_path.60
        path[61] = sun_path.61
        path[62] = sun_path.62
        path[63] = sun_path.63
        path[64] = sun_path.64
        path[65] = sun_path.65
        path[66] = sun_path.66
        path[67] = sun_path.67
        path[68] = sun_path.68
        path[69] = sun_path.69
        path[70] = sun_path.70
        path[71] = sun_path.71
        path[72] = sun_path.72
        path[73] = sun_path.73
        path[74] = sun_path.74
        path[75] = sun_path.75
        path[76] = sun_path.76
        path[77] = sun_path.77
        path[78] = sun_path.78
        path[79] = sun_path.79
        path[80] = sun_path.80
        path[81] = sun_path.81
        path[82] = sun_path.82
        path[83] = sun_path.83
        path[84] = sun_path.84
        path[85] = sun_path.85
        path[86] = sun_path.86
        path[87] = sun_path.87
        path[88] = sun_path.88
        path[89] = sun_path.89
        path[90] = sun_path.90
        path[91] = sun_path.91
        path[92] = sun_path.92
        path[93] = sun_path.93
        path[94] = sun_path.94
        path[95] = sun_path.95
        path[96] = sun_path.96
        path[97] = sun_path.97
        path[98] = sun_path.98
        path[99] = sun_path.99
        path[100] = sun_path.100
        path[101] = sun_path.101
        path[102] = sun_path.102
        path[103] = sun_path.103
        
        return path
    }
}


// end of file