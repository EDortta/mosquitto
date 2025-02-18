unit mosquitto;

{*
Copyright (c) 2010-2019 Roger Light <roger@atchoo.org>

All rights reserved. This program and the accompanying materials
are made available under the terms of the Eclipse Public License v1.0
and Eclipse Distribution License v1.0 which accompany this distribution.

The Eclipse Public License is available at
   http://www.eclipse.org/legal/epl-v10.html
and the Eclipse Distribution License is available at
  http://www.eclipse.org/org/documents/edl-v10.php.

Contributors:
   Roger Light - initial implementation and documentation.
*}

{*
 * Free Pascal header conversion
 * Copyright (c) 2018-2019 Karoly Balogh <charlie@amigaspirit.hu>
 *
 * http://github.com/chainq/mosquitto-p
 *}

{*
 * Dynamic loading of the mosquitto libray
 * Copyright (c) 2021-2022 Michel Deslierres
 *
 * https://github.com/sigmdel/mosquitto-p
 *
 * If the DYNAMIC_MOSQLIB macro is defined the mosquitto library is loaded
 * at run-time, otherwise the library is statically linked. See
 * function mosquitto_lib_loaded().
 *
 * $DEFINE DYNAMIC_MOSQLIB could be defined here, but it is best to
 * do that as an project option.
 *}

interface

uses
  ctypes {$IFDEF DYNAMIC_MOSQLIB}, dynlibs{$ENDIF};


{ This is a kludge, because apparently GCC is confused about
  how C booleans should work, and optimizes code away inside
  libmosquitto on some platforms, which breaks the 'non zero
  means true in C' assumption of FPC. (CB) }
type
    cbool = boolean; { longbool in ctypes }
    pcbool = ^cbool;

const
{$IFDEF HASUNIX}
{$IFDEF DARWIN}
{$LINKLIB mosquitto}
    libmosq_NAME = 'libmosquitto.dynlib';
{$ELSE}
    libmosq_NAME = 'libmosquitto.so';
{$ENDIF}
{$ELSE}
{$IFDEF MSWINDOWS}
    libmosq_NAME = 'mosquitto.dll';
{$ELSE}
{$ERROR Unsupported platform.}
{$ENDIF MSWINDOWS}
{$ENDIF HASUNIX}


const
    LIBMOSQUITTO_MAJOR = 1;
    LIBMOSQUITTO_MINOR = 5;
    LIBMOSQUITTO_REVISION = 8;
{* LIBMOSQUITTO_VERSION_NUMBER looks like 1002001 for e.g. version 1.2.1. *}
    LIBMOSQUITTO_VERSION_NUMBER = (LIBMOSQUITTO_MAJOR*1000000+LIBMOSQUITTO_MINOR*1000+LIBMOSQUITTO_REVISION);

{* Log types *}
const
    MOSQ_LOG_NONE = $00;
    MOSQ_LOG_INFO = $01;
    MOSQ_LOG_NOTICE = $02;
    MOSQ_LOG_WARNING = $04;
    MOSQ_LOG_ERR = $08;
    MOSQ_LOG_DEBUG = $10;
    MOSQ_LOG_SUBSCRIBE = $20;
    MOSQ_LOG_UNSUBSCRIBE = $40;
    MOSQ_LOG_WEBSOCKETS = $80;
    MOSQ_LOG_ALL = $FFFF;

{* Error values *}
const
    MOSQ_ERR_CONN_PENDING = -1;
    MOSQ_ERR_SUCCESS = 0;
    MOSQ_ERR_NOMEM = 1;
    MOSQ_ERR_PROTOCOL = 2;
    MOSQ_ERR_INVAL = 3;
    MOSQ_ERR_NO_CONN = 4;
    MOSQ_ERR_CONN_REFUSED = 5;
    MOSQ_ERR_NOT_FOUND = 6;
    MOSQ_ERR_CONN_LOST = 7;
    MOSQ_ERR_TLS = 8;
    MOSQ_ERR_PAYLOAD_SIZE = 9;
    MOSQ_ERR_NOT_SUPPORTED = 10;
    MOSQ_ERR_AUTH = 11;
    MOSQ_ERR_ACL_DENIED = 12;
    MOSQ_ERR_UNKNOWN = 13;
    MOSQ_ERR_ERRNO = 14;
    MOSQ_ERR_EAI = 15;
    MOSQ_ERR_PROXY = 16;
    MOSQ_ERR_PLUGIN_DEFER = 17;
    MOSQ_ERR_MALFORMED_UTF8 = 18;
    MOSQ_ERR_KEEPALIVE = 19;
    MOSQ_ERR_LOOKUP = 20;


{* Error values *}
const
    MOSQ_OPT_PROTOCOL_VERSION = 1;
    MOSQ_OPT_SSL_CTX = 2;
    MOSQ_OPT_SSL_CTX_WITH_DEFAULTS = 3;


{* MQTT specification restricts client ids to a maximum of 23 characters *}
const
    MOSQ_MQTT_ID_MAX_LENGTH = 23;

const
    MQTT_PROTOCOL_V31 = 3;
    MQTT_PROTOCOL_V311 = 4;

type
    PPmosquitto_message = ^Pmosquitto_message;
    Pmosquitto_message = ^Tmosquitto_message;
    Tmosquitto_message = record
        mid: cint;
        topic: pchar;
        payload: pointer;
        payloadlen: cint;
        qos: cint;
        retain: cbool;
    end;

type
    Pmosquitto = ^Tmosquitto;
    Tmosquitto = type array of byte;


{*
 * Topic: Threads
 *	libmosquitto provides thread safe operation, with the exception of
 *	<mosquitto_lib_init> which is not thread safe.
 *
 *	If your application uses threads you must use <mosquitto_threaded_set> to
 *	tell the library this is the case, otherwise it makes some optimisations
 *	for the single threaded case that may result in unexpected behaviour for
 *	the multi threaded case.
 *}
{***************************************************
 * Important note
 * 
 * The following functions that deal with network operations will return
 * MOSQ_ERR_SUCCESS on success, but this does not mean that the operation has
 * taken place. An attempt will be made to write the network data, but if the
 * socket is not available for writing at that time then the packet will not be
 * sent. To ensure the packet is sent, call mosquitto_loop() (which must also
 * be called to process incoming network data).
 * This is especially important when disconnecting a client that has a will. If
 * the broker does not receive the DISCONNECT command, it will assume that the
 * client has disconnected unexpectedly and send the will.
 *
 * mosquitto_connect()
 * mosquitto_disconnect()
 * mosquitto_subscribe()
 * mosquitto_unsubscribe()
 * mosquitto_publish()
 ***************************************************}


 {*
  * Function: mosquitto_lib_loaded
  *
  * Returns:
  *     True if the mosquitto library was loaded during the program's
  *         initialization
  *
  * If the DYNAMIC_MOSQLIB macro is not defined then the mosquitto library
  * is statically linked. If the library is installed on the system, the
  * function returns true. If the library is not installed on the system
  * the program will abort at the very start and any call to this function
  * will not be made.
  *
  * If the DYNAMIC_MOSQLIB macro is defined then the function will return
  * false if the mosquitto library is not installed in the system or
  * if it was impossible to assign any one of the library functions or
  * procedures. Program execution will continue.
  *}
function mosquitto_lib_loaded(): boolean;

{*
 * Function: mosquitto_lib_version
 *
 * Can be used to obtain version information for the mosquitto library.
 * This allows the application to compare the library version against the
 * version it was compiled against by using the LIBMOSQUITTO_MAJOR,
 * LIBMOSQUITTO_MINOR and LIBMOSQUITTO_REVISION defines.
 *
 * Parameters:
 *  major -    an integer pointer. If not NULL, the major version of the
 *             library will be returned in this variable.
 *  minor -    an integer pointer. If not NULL, the minor version of the
 *             library will be returned in this variable.
 *  revision - an integer pointer. If not NULL, the revision of the library will
 *             be returned in this variable.
 *
 * Returns:
 *	LIBMOSQUITTO_VERSION_NUMBER, which is a unique number based on the major,
 *		minor and revision values.
 * See Also:
 * 	<mosquitto_lib_cleanup>, <mosquitto_lib_init>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_lib_version(major: pcint; minor: pcint; revision: pcint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibVersionFuction = function(major: pcint; minor: pcint; revision: pcint): cint; cdecl;
var
  mosquitto_lib_version:  TMosqLibVersionFuction;
{$ENDIF}


{*
 * Function: mosquitto_lib_init
 *
 * Must be called before any other mosquitto functions.
 *
 * This function is *not* thread safe.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - always
 *
 * See Also:
 * 	<mosquitto_lib_cleanup>, <mosquitto_lib_version>
 *}
 {$IFNDEF DYNAMIC_MOSQLIB}
 function mosquitto_lib_init: cint; cdecl; external libmosq_NAME;
 {$ELSE}
 Type
   TMosqLibInitFunction = function(): cint; cdecl;
 var
   mosquitto_lib_init: TMosqLibInitFunction;
 {$ENDIF}


{*
 * Function: mosquitto_lib_cleanup
 *
 * Call to free resources associated with the library.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - always
 *
 * See Also:
 * 	<mosquitto_lib_init>, <mosquitto_lib_version>
 *}
 {$IFNDEF DYNAMIC_MOSQLIB}
 function mosquitto_lib_cleanup: cint; cdecl; external libmosq_NAME;
 {$ELSE}
 Type
   TMosqLibCleanupFunction = function(): cint; cdecl;
 var
   mosquitto_lib_cleanup: TMosqLibCleanupFunction;
 {$ENDIF}


{*
 * Function: mosquitto_new
 *
 * Create a new mosquitto client instance.
 *
 * Parameters:
 * 	id -            String to use as the client id. If NULL, a random client id
 * 	                will be generated. If id is NULL, clean_session must be true.
 * 	clean_session - set to true to instruct the broker to clean all messages
 *                  and subscriptions on disconnect, false to instruct it to
 *                  keep them. See the man page mqtt(7) for more details.
 *                  Note that a client will never discard its own outgoing
 *                  messages on disconnect. Calling <mosquitto_connect> or
 *                  <mosquitto_reconnect> will cause the messages to be resent.
 *                  Use <mosquitto_reinitialise> to reset a client to its
 *                  original state.
 *                  Must be set to true if the id parameter is NULL.
 * 	obj -           A user pointer that will be passed as an argument to any
 *                  callbacks that are specified.
 *
 * Returns:
 * 	Pointer to a struct mosquitto on success.
 * 	NULL on failure. Interrogate errno to determine the cause for the failure:
 *      - ENOMEM on out of memory.
 *      - EINVAL on invalid input parameters.
 *
 * See Also:
 * 	<mosquitto_reinitialise>, <mosquitto_destroy>, <mosquitto_user_data_set>
 *}


{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_new(const id: PChar; clean_session: cbool; obj: Pointer): Pmosquitto; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibNewFunction = function(const id: PChar; clean_session: cbool; obj: Pointer): Pmosquitto; cdecl;
var
  mosquitto_new: TMosqLibNewFunction;
{$ENDIF}


{*
 * Function: mosquitto_destroy
 *
 * Use to free memory associated with a mosquitto client instance.
 *
 * Parameters:
 * 	mosq - a struct mosquitto pointer to free.
 *
 * See Also:
 * 	<mosquitto_new>, <mosquitto_reinitialise>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_destroy(mosq: Pmosquitto); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibDestroyProcedure = procedure(mosq: Pmosquitto); cdecl;
var
  mosquitto_destroy: TMosqLibDestroyProcedure;
{$ENDIF}

{*
 * Function: mosquitto_reinitialise
 *
 * This function allows an existing mosquitto client to be reused. Call on a
 * mosquitto instance to close any open network connections, free memory
 * and reinitialise the client with the new parameters. The end result is the
 * same as the output of <mosquitto_new>.
 *
 * Parameters:
 * 	mosq -          a valid mosquitto instance.
 * 	id -            string to use as the client id. If NULL, a random client id
 * 	                will be generated. If id is NULL, clean_session must be true.
 * 	clean_session - set to true to instruct the broker to clean all messages
 *                  and subscriptions on disconnect, false to instruct it to
 *                  keep them. See the man page mqtt(7) for more details.
 *                  Must be set to true if the id parameter is NULL.
 * 	obj -           A user pointer that will be passed as an argument to any
 *                  callbacks that are specified.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * See Also:
 * 	<mosquitto_new>, <mosquitto_destroy>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_reinitialise(mosq: Pmosquitto; const id: Pchar; clean_session: cbool; obj: Pointer): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibReinitialiseFunction = function(mosq: Pmosquitto; const id: Pchar; clean_session: cbool; obj: Pointer): cint; cdecl;
var
  mosquitto_reinitialise: TMosqLibReinitialiseFunction;
{$ENDIF}


{*
 * Function: mosquitto_will_set
 *
 * Configure will information for a mosquitto instance. By default, clients do
 * not have a will.  This must be called before calling <mosquitto_connect>.
 *
 * Parameters:
 * 	mosq -       a valid mosquitto instance.
 * 	topic -      the topic on which to publish the will.
 * 	payloadlen - the size of the payload (bytes). Valid values are between 0 and
 *               268,435,455.
 * 	payload -    pointer to the data to send. If payloadlen > 0 this must be a
 *               valid memory location.
 * 	qos -        integer value 0, 1 or 2 indicating the Quality of Service to be
 *               used for the will.
 * 	retain -     set to true to make the will a retained message.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS -      on success.
 * 	MOSQ_ERR_INVAL -          if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -          if an out of memory condition occurred.
 * 	MOSQ_ERR_PAYLOAD_SIZE -   if payloadlen is too large.
 * 	MOSQ_ERR_MALFORMED_UTF8 - if the topic is not valid UTF-8.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_will_set(mosq: Pmosquitto; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibWillSetFunction = function (mosq: Pmosquitto; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl;
var
  mosquitto_will_set: TMosqLibWillSetFunction;
{$ENDIF}

{*
 * Function: mosquitto_will_clear
 *
 * Remove a previously configured will. This must be called before calling
 * <mosquitto_connect>.
 *
 * Parameters:
 * 	mosq - a valid mosquitto instance.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_will_clear(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibWillClearFunction = function (mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_will_clear: TMosqLibWillClearFunction;
{$ENDIF}

{*
 * Function: mosquitto_username_pw_set
 *
 * Configure username and password for a mosquitton instance. This is only
 * supported by brokers that implement the MQTT spec v3.1. By default, no
 * username or password will be sent.
 * If username is NULL, the password argument is ignored.
 * This must be called before calling mosquitto_connect().
 *
 * This is must be called before calling <mosquitto_connect>.
 *
 * Parameters:
 * 	mosq -     a valid mosquitto instance.
 * 	username - the username to send as a string, or NULL to disable
 *             authentication.
 * 	password - the password to send as a string. Set to NULL when username is
 * 	           valid in order to send just a username.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_username_pw_set(mosq: Pmosquitto; const username: pchar; const password: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibUsernamePwSetFunction = function (mosq: Pmosquitto; const username: pchar; const password: pchar): cint; cdecl;
var
  mosquitto_username_pw_set: TMosqLibUsernamePwSetFunction;
{$ENDIF}

{*
 * Function: mosquitto_connect
 *
 * Connect to an MQTT broker.
 *
 * Parameters:
 * 	mosq -      a valid mosquitto instance.
 * 	host -      the hostname or ip address of the broker to connect to.
 * 	port -      the network port to connect to. Usually 1883.
 * 	keepalive - the number of seconds after which the broker should send a PING
 *              message to the client if no other messages have been exchanged
 *              in that time.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect_bind>, <mosquitto_connect_async>, <mosquitto_reconnect>, <mosquitto_disconnect>, <mosquitto_tls_set>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_connect(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnectFunction = function(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl;
var
  mosquitto_connect: TMosqLibConnectFunction;
{$ENDIF}


{*
 * Function: mosquitto_connect_bind
 *
 * Connect to an MQTT broker. This extends the functionality of
 * <mosquitto_connect> by adding the bind_address parameter. Use this function
 * if you need to restrict network communication over a particular interface. 
 *
 * Parameters:
 * 	mosq -         a valid mosquitto instance.
 * 	host -         the hostname or ip address of the broker to connect to.
 * 	port -         the network port to connect to. Usually 1883.
 * 	keepalive -    the number of seconds after which the broker should send a PING
 *                 message to the client if no other messages have been exchanged
 *                 in that time.
 *  bind_address - the hostname or ip address of the local network interface to
 *                 bind to.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect>, <mosquitto_connect_async>, <mosquitto_connect_bind_async>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_connect_bind(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnectBindFunction = function(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl;
var
  mosquitto_connect_bind: TMosqLibConnectBindFunction;
{$ENDIF}

{*
 * Function: mosquitto_connect_async
 *
 * Connect to an MQTT broker. This is a non-blocking call. If you use
 * <mosquitto_connect_async> your client must use the threaded interface
 * <mosquitto_loop_start>. If you need to use <mosquitto_loop>, you must use
 * <mosquitto_connect> to connect the client.
 *
 * May be called before or after <mosquitto_loop_start>.
 *
 * Parameters:
 * 	mosq -      a valid mosquitto instance.
 * 	host -      the hostname or ip address of the broker to connect to.
 * 	port -      the network port to connect to. Usually 1883.
 * 	keepalive - the number of seconds after which the broker should send a PING
 *              message to the client if no other messages have been exchanged
 *              in that time.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect_bind_async>, <mosquitto_connect>, <mosquitto_reconnect>, <mosquitto_disconnect>, <mosquitto_tls_set>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_connect_async(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
type
  TMosqLibConnectAsyncFunction = function(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl;
var
  mosquitto_connect_async: TMosqLibConnectAsyncFunction;
{$ENDIF}
{*
 * Function: mosquitto_connect_bind_async
 *
 * Connect to an MQTT broker. This is a non-blocking call. If you use
 * <mosquitto_connect_bind_async> your client must use the threaded interface
 * <mosquitto_loop_start>. If you need to use <mosquitto_loop>, you must use
 * <mosquitto_connect> to connect the client.
 *
 * This extends the functionality of <mosquitto_connect_async> by adding the
 * bind_address parameter. Use this function if you need to restrict network
 * communication over a particular interface. 
 *
 * May be called before or after <mosquitto_loop_start>.
 *
 * Parameters:
 * 	mosq -         a valid mosquitto instance.
 * 	host -         the hostname or ip address of the broker to connect to.
 * 	port -         the network port to connect to. Usually 1883.
 * 	keepalive -    the number of seconds after which the broker should send a PING
 *                 message to the client if no other messages have been exchanged
 *                 in that time.
 *  bind_address - the hostname or ip address of the local network interface to
 *                 bind to.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect_async>, <mosquitto_connect>, <mosquitto_connect_bind>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_connect_bind_async(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnectBindAsyncFunction = function(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl;
var
  mosquitto_connect_bind_async: TMosqLibConnectBindAsyncFunction;
{$ENDIF}

{*
 * Function: mosquitto_connect_srv
 *
 * Connect to an MQTT broker. This is a non-blocking call. If you use
 * <mosquitto_connect_async> your client must use the threaded interface
 * <mosquitto_loop_start>. If you need to use <mosquitto_loop>, you must use
 * <mosquitto_connect> to connect the client.
 *
 * This extends the functionality of <mosquitto_connect_async> by adding the
 * bind_address parameter. Use this function if you need to restrict network
 * communication over a particular interface. 
 *
 * May be called before or after <mosquitto_loop_start>.
 *
 * Parameters:
 * 	mosq -         a valid mosquitto instance.
 * 	host -         the hostname or ip address of the broker to connect to.
 * 	keepalive -    the number of seconds after which the broker should send a PING
 *                 message to the client if no other messages have been exchanged
 *                 in that time.
 *  bind_address - the hostname or ip address of the local network interface to
 *                 bind to.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect_async>, <mosquitto_connect>, <mosquitto_connect_bind>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_connect_srv(mosq: Pmosquitto; const host: pchar; keepalive: cint; const bind_address: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnectSrvFunction = function(mosq: Pmosquitto; const host: pchar; keepalive: cint; const bind_address: pchar): cint; cdecl;
var
  mosquitto_connect_srv: TMosqLibConnectSrvFunction;
{$ENDIF}

{*
 * Function: mosquitto_reconnect
 *
 * Reconnect to a broker.
 *
 * This function provides an easy way of reconnecting to a broker after a
 * connection has been lost. It uses the values that were provided in the
 * <mosquitto_connect> call. It must not be called before
 * <mosquitto_connect>.
 *
 * Parameters:
 * 	mosq - a valid mosquitto instance.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect>, <mosquitto_disconnect>, <mosquitto_reconnect_async>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_reconnect(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibReconnectFunction = function(mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_reconnect: TMosqLibReconnectFunction;
{$ENDIF}

{*
 * Function: mosquitto_reconnect_async
 *
 * Reconnect to a broker. Non blocking version of <mosquitto_reconnect>.
 *
 * This function provides an easy way of reconnecting to a broker after a
 * connection has been lost. It uses the values that were provided in the
 * <mosquitto_connect> or <mosquitto_connect_async> calls. It must not be
 * called before <mosquitto_connect>.
 *
 * Parameters:
 * 	mosq - a valid mosquitto instance.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * Returns:
 * 	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_ERRNO -   if a system call returned an error. The variable errno
 *                     contains the error code, even on Windows.
 *                     Use strerror_r() where available or FormatMessage() on
 *                     Windows.
 *
 * See Also:
 * 	<mosquitto_connect>, <mosquitto_disconnect>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_reconnect_async(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibReconnectAsyncFunction = function(mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_reconnect_async: TMosqLibReconnectAsyncFunction;
{$ENDIF}

{*
 * Function: mosquitto_disconnect
 *
 * Disconnect from the broker.
 *
 * Parameters:
 *	mosq - a valid mosquitto instance.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NO_CONN -  if the client isn't connected to a broker.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_disconnect(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibDisconnectFunction = function(mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_disconnect: TMosqLibDisconnectFunction;
{$ENDIF}

{*
 * Function: mosquitto_publish
 *
 * Publish a message on a given topic.
 *
 * Parameters:
 * 	mosq -       a valid mosquitto instance.
 * 	mid -        pointer to an int. If not NULL, the function will set this
 *               to the message id of this particular message. This can be then
 *               used with the publish callback to determine when the message
 *               has been sent.
 *               Note that although the MQTT protocol doesn't use message ids
 *               for messages with QoS=0, libmosquitto assigns them message ids
 *               so they can be tracked with this parameter.
 *  topic -      null terminated string of the topic to publish to.
 * 	payloadlen - the size of the payload (bytes). Valid values are between 0 and
 *               268,435,455.
 * 	payload -    pointer to the data to send. If payloadlen > 0 this must be a
 *               valid memory location.
 * 	qos -        integer value 0, 1 or 2 indicating the Quality of Service to be
 *               used for the message.
 * 	retain -     set to true to make the message retained.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -        on success.
 * 	MOSQ_ERR_INVAL -          if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -          if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -        if the client isn't connected to a broker.
 * 	MOSQ_ERR_PROTOCOL -       if there is a protocol error communicating with the
 *                            broker.
 * 	MOSQ_ERR_PAYLOAD_SIZE -   if payloadlen is too large.
 * 	MOSQ_ERR_MALFORMED_UTF8 - if the topic is not valid UTF-8
 * See Also:
 *	<mosquitto_max_inflight_messages_set>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_publish(mosq: Pmosquitto; mid: pcint; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibPublishFunction = function(mosq: Pmosquitto; mid: pcint; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl;
var
  mosquitto_publish: TMosqLibPublishFunction;
{$ENDIF}

{*
 * Function: mosquitto_subscribe
 *
 * Subscribe to a topic.
 *
 * Parameters:
 *	mosq - a valid mosquitto instance.
 *	mid -  a pointer to an int. If not NULL, the function will set this to
 *	       the message id of this particular message. This can be then used
 *	       with the subscribe callback to determine when the message has been
 *	       sent.
 *	sub -  the subscription pattern.
 *	qos -  the requested Quality of Service for this subscription.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -        on success.
 * 	MOSQ_ERR_INVAL -          if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -          if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -        if the client isn't connected to a broker.
 * 	MOSQ_ERR_MALFORMED_UTF8 - if the topic is not valid UTF-8
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_subscribe(mosq: Pmosquitto; mid: pcint; const sub: pchar; qos: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubscribeFunction = function(mosq: Pmosquitto; mid: pcint; const sub: pchar; qos: cint): cint; cdecl;
var
  mosquitto_subscribe: TMosqLibSubscribeFunction;
{$ENDIF}

{*
 * Function: mosquitto_unsubscribe
 *
 * Unsubscribe from a topic.
 *
 * Parameters:
 *	mosq - a valid mosquitto instance.
 *	mid -  a pointer to an int. If not NULL, the function will set this to
 *	       the message id of this particular message. This can be then used
 *	       with the unsubscribe callback to determine when the message has been
 *	       sent.
 *	sub -  the unsubscription pattern.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -        on success.
 * 	MOSQ_ERR_INVAL -          if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -          if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -        if the client isn't connected to a broker.
 * 	MOSQ_ERR_MALFORMED_UTF8 - if the topic is not valid UTF-8
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_unsubscribe(mosq: Pmosquitto; mid: pcint; const sub: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibUnsubscribeFunction = function(mosq: Pmosquitto; mid: pcint; const sub: pchar): cint; cdecl;
var
  mosquitto_unsubscribe: TMosqLibUnsubscribeFunction;
{$ENDIF}

{*
 * Function: mosquitto_message_copy
 *
 * Copy the contents of a mosquitto message to another message.
 * Useful for preserving a message received in the on_message() callback.
 *
 * Parameters:
 *	dst - a pointer to a valid mosquitto_message struct to copy to.
 *	src - a pointer to a valid mosquitto_message struct to copy from.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * See Also:
 * 	<mosquitto_message_free>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_message_copy(dst: Pmosquitto_message; const src: Pmosquitto_message): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibMessageCopyFunction = function(dst: Pmosquitto_message; const src: Pmosquitto_message): cint; cdecl;
var
  mosquitto_message_copy: TMosqLibMessageCopyFunction;
{$ENDIF}

{*
 * Function: mosquitto_message_free
 *
 * Completely free a mosquitto_message struct.
 *
 * Parameters:
 *	message - pointer to a mosquitto_message pointer to free.
 *
 * See Also:
 * 	<mosquitto_message_copy>, <mosquitto_message_free_contents>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_message_free(message: PPmosquitto_message); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibMessageFreeProcedure = procedure(mosquitto_message: Pmosquitto_message); cdecl;
var
  mosquitto_message_free: TMosqLibMessageFreeProcedure;
{$ENDIF}

{*
 * Function: mosquitto_message_free_contents
 *
 * Free a mosquitto_message struct contents, leaving the struct unaffected.
 *
 * Parameters:
 *	message - pointer to a mosquitto_message struct to free its contents.
 *
 * See Also:
 * 	<mosquitto_message_copy>, <mosquitto_message_free>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_message_free_contents(mosquitto_message: Pmosquitto_message); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibMessageFreeContentsProcedure = procedure(mosquitto_message: Pmosquitto_message); cdecl;
var
  mosquitto_message_free_contents: TMosqLibMessageFreeContentsProcedure;
{$ENDIF}

{*
 * Function: mosquitto_loop
 *
 * The main network loop for the client. You must call this frequently in order
 * to keep communications between the client and broker working. If incoming
 * data is present it will then be processed. Outgoing commands, from e.g.
 * <mosquitto_publish>, are normally sent immediately that their function is
 * called, but this is not always possible. <mosquitto_loop> will also attempt
 * to send any remaining outgoing messages, which also includes commands that
 * are part of the flow for messages with QoS>0.
 *
 * An alternative approach is to use <mosquitto_loop_start> to run the client
 * loop in its own thread.
 *
 * This calls select() to monitor the client network socket. If you want to
 * integrate mosquitto client operation with your own select() call, use
 * <mosquitto_socket>, <mosquitto_loop_read>, <mosquitto_loop_write> and
 * <mosquitto_loop_misc>.
 *
 * Threads:
 *	
 * Parameters:
 *	mosq -        a valid mosquitto instance.
 *	timeout -     Maximum number of milliseconds to wait for network activity
 *	              in the select() call before timing out. Set to 0 for instant
 *	              return.  Set negative to use the default of 1000ms.
 *	max_packets - this parameter is currently unused and should be set to 1 for
 *	              future compatibility.
 * 
 * Returns:
 *	MOSQ_ERR_SUCCESS -   on success.
 * 	MOSQ_ERR_INVAL -     if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -     if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -   if the client isn't connected to a broker.
 *  MOSQ_ERR_CONN_LOST - if the connection to the broker was lost.
 *	MOSQ_ERR_PROTOCOL -  if there is a protocol error communicating with the
 *                       broker.
 * 	MOSQ_ERR_ERRNO -     if a system call returned an error. The variable errno
 *                       contains the error code, even on Windows.
 *                       Use strerror_r() where available or FormatMessage() on
 *                       Windows.
 * See Also:
 *	<mosquitto_loop_forever>, <mosquitto_loop_start>, <mosquitto_loop_stop>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopFunction = function(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl;
var
  mosquitto_loop: TMosqLibLoopFunction;
{$ENDIF}


{*
 * Function: mosquitto_loop_forever
 *
 * This function call loop() for you in an infinite blocking loop. It is useful
 * for the case where you only want to run the MQTT client loop in your
 * program.
 *
 * It handles reconnecting in case server connection is lost. If you call
 * mosquitto_disconnect() in a callback it will return.
 *
 * Parameters:
 *  mosq - a valid mosquitto instance.
 *	timeout -     Maximum number of milliseconds to wait for network activity
 *	              in the select() call before timing out. Set to 0 for instant
 *	              return.  Set negative to use the default of 1000ms.
 *	max_packets - this parameter is currently unused and should be set to 1 for
 *	              future compatibility.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -   on success.
 * 	MOSQ_ERR_INVAL -     if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -     if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -   if the client isn't connected to a broker.
 *  MOSQ_ERR_CONN_LOST - if the connection to the broker was lost.
 *	MOSQ_ERR_PROTOCOL -  if there is a protocol error communicating with the
 *                       broker.
 * 	MOSQ_ERR_ERRNO -     if a system call returned an error. The variable errno
 *                       contains the error code, even on Windows.
 *                       Use strerror_r() where available or FormatMessage() on
 *                       Windows.
 *
 * See Also:
 *	<mosquitto_loop>, <mosquitto_loop_start>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop_forever(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopForeverFunction = function(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl;
var
  mosquitto_loop_forever: TMosqLibLoopForeverFunction;
{$ENDIF}

{*
 * Function: mosquitto_loop_start
 *
 * This is part of the threaded client interface. Call this once to start a new
 * thread to process network traffic. This provides an alternative to
 * repeatedly calling <mosquitto_loop> yourself.
 *
 * Parameters:
 *  mosq - a valid mosquitto instance.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -       on success.
 * 	MOSQ_ERR_INVAL -         if the input parameters were invalid.
 *	MOSQ_ERR_NOT_SUPPORTED - if thread support is not available.
 *
 * See Also:
 *	<mosquitto_connect_async>, <mosquitto_loop>, <mosquitto_loop_forever>, <mosquitto_loop_stop>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop_start(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopStartFunction = function(mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_loop_start: TMosqLibLoopStartFunction;
{$ENDIF}


{*
 * Function: mosquitto_loop_stop
 *
 * This is part of the threaded client interface. Call this once to stop the
 * network thread previously created with <mosquitto_loop_start>. This call
 * will block until the network thread finishes. For the network thread to end,
 * you must have previously called <mosquitto_disconnect> or have set the force
 * parameter to true.
 *
 * Parameters:
 *  mosq - a valid mosquitto instance.
 *	force - set to true to force thread cancellation. If false,
 *	        <mosquitto_disconnect> must have already been called.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -       on success.
 * 	MOSQ_ERR_INVAL -         if the input parameters were invalid.
 *	MOSQ_ERR_NOT_SUPPORTED - if thread support is not available.
 *
 * See Also:
 *	<mosquitto_loop>, <mosquitto_loop_start>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop_stop(mosq: Pmosquitto; force: cbool): cint; cdecl external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopStopFunction = function(mosq: Pmosquitto; force: cbool): cint; cdecl;
var
  mosquitto_loop_stop: TMosqLibLoopStopFunction;
{$ENDIF}


{*
 * Function: mosquitto_socket
 *
 * Return the socket handle for a mosquitto instance. Useful if you want to
 * include a mosquitto client in your own select() calls.
 *
 * Parameters:
 *	mosq - a valid mosquitto instance.
 *
 * Returns:
 *	The socket for the mosquitto client or -1 on failure.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_socket(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
type
  TMosqLibSocketFunction = function(mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_socket: TMosqLibSocketFunction;
{$ENDIF}


{*
 * Function: mosquitto_loop_read
 *
 * Carry out network read operations.
 * This should only be used if you are not using mosquitto_loop() and are
 * monitoring the client network socket for activity yourself.
 *
 * Parameters:
 *	mosq -        a valid mosquitto instance.
 *	max_packets - this parameter is currently unused and should be set to 1 for
 *	              future compatibility.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -   on success.
 * 	MOSQ_ERR_INVAL -     if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -     if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -   if the client isn't connected to a broker.
 *  MOSQ_ERR_CONN_LOST - if the connection to the broker was lost.
 *	MOSQ_ERR_PROTOCOL -  if there is a protocol error communicating with the
 *                       broker.
 * 	MOSQ_ERR_ERRNO -     if a system call returned an error. The variable errno
 *                       contains the error code, even on Windows.
 *                       Use strerror_r() where available or FormatMessage() on
 *                       Windows.
 *
 * See Also:
 *	<mosquitto_socket>, <mosquitto_loop_write>, <mosquitto_loop_misc>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop_read(mosq: Pmosquitto; max_packets: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopReadFunction = function(mosq: Pmosquitto; max_packets: cint): cint; cdecl;
var
  mosquitto_loop_read: TMosqLibLoopReadFunction;
{$ENDIF}

{*
 * Function: mosquitto_loop_write
 *
 * Carry out network write operations.
 * This should only be used if you are not using mosquitto_loop() and are
 * monitoring the client network socket for activity yourself.
 *
 * Parameters:
 *	mosq -        a valid mosquitto instance.
 *	max_packets - this parameter is currently unused and should be set to 1 for
 *	              future compatibility.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -   on success.
 * 	MOSQ_ERR_INVAL -     if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -     if an out of memory condition occurred.
 * 	MOSQ_ERR_NO_CONN -   if the client isn't connected to a broker.
 *  MOSQ_ERR_CONN_LOST - if the connection to the broker was lost.
 *	MOSQ_ERR_PROTOCOL -  if there is a protocol error communicating with the
 *                       broker.
 * 	MOSQ_ERR_ERRNO -     if a system call returned an error. The variable errno
 *                       contains the error code, even on Windows.
 *                       Use strerror_r() where available or FormatMessage() on
 *                       Windows.
 *
 * See Also:
 *	<mosquitto_socket>, <mosquitto_loop_read>, <mosquitto_loop_misc>, <mosquitto_want_write>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop_write(mosq: Pmosquitto; max_packets: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopWriteFunction = function(mosq: Pmosquitto; max_packets: cint): cint; cdecl;
var
  mosquitto_loop_write: TMosqLibLoopWriteFunction;
{$ENDIF}

{*
 * Function: mosquitto_loop_misc
 *
 * Carry out miscellaneous operations required as part of the network loop.
 * This should only be used if you are not using mosquitto_loop() and are
 * monitoring the client network socket for activity yourself.
 *
 * This function deals with handling PINGs and checking whether messages need
 * to be retried, so should be called fairly frequently.
 *
 * Parameters:
 *	mosq - a valid mosquitto instance.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -   on success.
 * 	MOSQ_ERR_INVAL -     if the input parameters were invalid.
 * 	MOSQ_ERR_NO_CONN -   if the client isn't connected to a broker.
 *
 * See Also:
 *	<mosquitto_socket>, <mosquitto_loop_read>, <mosquitto_loop_write>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_loop_misc(mosq: Pmosquitto): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLoopMiscFunction = function(mosq: Pmosquitto): cint; cdecl;
var
  mosquitto_loop_misc: TMosqLibLoopMiscFunction;
{$ENDIF}

{*
 * Function: mosquitto_want_write
 *
 * Returns true if there is data ready to be written on the socket.
 *
 * Parameters:
 *	mosq - a valid mosquitto instance.
 *
 * See Also:
 *	<mosquitto_socket>, <mosquitto_loop_read>, <mosquitto_loop_write>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_want_write(mosq: Pmosquitto): cbool; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibWantWriteFunction = function(mosq: Pmosquitto): cbool; cdecl;
var
  mosquitto_want_write: TMosqLibWantWriteFunction;
{$ENDIF}


{*
 * Function: mosquitto_threaded_set
 *
 * Used to tell the library that your application is using threads, but not
 * using <mosquitto_loop_start>. The library operates slightly differently when
 * not in threaded mode in order to simplify its operation. If you are managing
 * your own threads and do not use this function you will experience crashes
 * due to race conditions.
 *
 * When using <mosquitto_loop_start>, this is set automatically.
 *
 * Parameters:
 *  mosq -     a valid mosquitto instance.
 *  threaded - true if your application is using threads, false otherwise.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_threaded_set(mosq: Pmosquitto; threaded: cbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibThreadedSetFunction = function(mosq: Pmosquitto; threaded: cbool): cint; cdecl;
var
  mosquitto_threaded_set: TMosqLibThreadedSetFunction;
{$ENDIF}

{*
 * Function: mosquitto_opts_set
 *
 * Used to set options for the client.
 *
 * Parameters:
 *	mosq -   a valid mosquitto instance.
 *	option - the option to set.
 *	value -  the option specific value.
 *
 * Options:
 *	MOSQ_OPT_PROTOCOL_VERSION
 *	          Value must be an int, set to either MQTT_PROTOCOL_V31 or
 *	          MQTT_PROTOCOL_V311. Must be set before the client connects.
 *	          Defaults to MQTT_PROTOCOL_V31.
 *
 *	MOSQ_OPT_SSL_CTX
 *	          Pass an openssl SSL_CTX to be used when creating TLS connections
 *	          rather than libmosquitto creating its own.  This must be called
 *	          before connecting to have any effect. If you use this option, the
 *	          onus is on you to ensure that you are using secure settings.
 *	          Setting to NULL means that libmosquitto will use its own SSL_CTX
 *	          if TLS is to be used.
 *	          This option is only available for openssl 1.1.0 and higher.
 *
 *	MOSQ_OPT_SSL_CTX_WITH_DEFAULTS
 *	          Value must be an int set to 1 or 0. If set to 1, then the user
 *	          specified SSL_CTX passed in using MOSQ_OPT_SSL_CTX will have the
 *	          default options applied to it. This means that you only need to
 *	          change the values that are relevant to you. If you use this
 *	          option then you must configure the TLS options as normal, i.e.
 *	          you should use <mosquitto_tls_set> to configure the cafile/capath
 *	          as a minimum.
 *	          This option is only available for openssl 1.1.0 and higher.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_opts_set(mosq: Pmosquitto; option: cint; value: pointer): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibOptsSetFunction = function(mosq: Pmosquitto; option: cint; value: pointer): cint; cdecl;
var
  mosquitto_opts_set: TMosqLibOptsSetFunction;
{$ENDIF}

{*
 * Function: mosquitto_tls_set
 *
 * Configure the client for certificate based SSL/TLS support. Must be called
 * before <mosquitto_connect>.
 *
 * Cannot be used in conjunction with <mosquitto_tls_psk_set>.
 *
 * Define the Certificate Authority certificates to be trusted (ie. the server
 * certificate must be signed with one of these certificates) using cafile.
 *
 * If the server you are connecting to requires clients to provide a
 * certificate, define certfile and keyfile with your client certificate and
 * private key. If your private key is encrypted, provide a password callback
 * function or you will have to enter the password at the command line.
 *
 * Parameters:
 *  mosq -        a valid mosquitto instance.
 *  cafile -      path to a file containing the PEM encoded trusted CA
 *                certificate files. Either cafile or capath must not be NULL.
 *  capath -      path to a directory containing the PEM encoded trusted CA
 *                certificate files. See mosquitto.conf for more details on
 *                configuring this directory. Either cafile or capath must not
 *                be NULL.
 *  certfile -    path to a file containing the PEM encoded certificate file
 *                for this client. If NULL, keyfile must also be NULL and no
 *                client certificate will be used.
 *  keyfile -     path to a file containing the PEM encoded private key for
 *                this client. If NULL, certfile must also be NULL and no
 *                client certificate will be used.
 *  pw_callback - if keyfile is encrypted, set pw_callback to allow your client
 *                to pass the correct password for decryption. If set to NULL,
 *                the password must be entered on the command line.
 *                Your callback must write the password into "buf", which is
 *                "size" bytes long. The return value must be the length of the
 *                password. "userdata" will be set to the calling mosquitto
 *                instance. The mosquitto userdata member variable can be
 *                retrieved using <mosquitto_userdata>.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * See Also:
 *	<mosquitto_tls_opts_set>, <mosquitto_tls_psk_set>,
 *	<mosquitto_tls_insecure_set>, <mosquitto_userdata>
 *}
type
    Tpw_callback = function(buf: pchar; size: cint; rwflag: cint; userdata: pointer): cint; cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_tls_set(mosq: Pmosquitto;
		const cafile: pchar; const capath: pchar;
		const certfile: pchar; const keyfile: pchar;
		pw_callback: Tpw_callback): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibTlsSetFunction = function(mosq: Pmosquitto;
		const cafile: pchar; const capath: pchar;
		const certfile: pchar; const keyfile: pchar;
		pw_callback: Tpw_callback): cint; cdecl;
var
  mosquitto_tls_set: TMosqLibTlsSetFunction;
{$ENDIF}


{*
 * Function: mosquitto_tls_insecure_set
 *
 * Configure verification of the server hostname in the server certificate. If
 * value is set to true, it is impossible to guarantee that the host you are
 * connecting to is not impersonating your server. This can be useful in
 * initial server testing, but makes it possible for a malicious third party to
 * impersonate your server through DNS spoofing, for example.
 * Do not use this function in a real system. Setting value to true makes the
 * connection encryption pointless.
 * Must be called before <mosquitto_connect>.
 *
 * Parameters:
 *  mosq -  a valid mosquitto instance.
 *  value - if set to false, the default, certificate hostname checking is
 *          performed. If set to true, no hostname checking is performed and
 *          the connection is insecure.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 *
 * See Also:
 *	<mosquitto_tls_set>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_tls_insecure_set(mosq: Pmosquitto; value: cbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
type
  TMosqLibTlsInsecureSetFunction = function (mosq: Pmosquitto; value: cbool): cint; cdecl;
var
  mosquitto_tls_insecure_set: TMosqLibTlsInsecureSetFunction;
{$ENDIF}

{*
 * Function: mosquitto_tls_opts_set
 *
 * Set advanced SSL/TLS options. Must be called before <mosquitto_connect>.
 *
 * Parameters:
 *  mosq -        a valid mosquitto instance.
 *	cert_reqs -   an integer defining the verification requirements the client
 *	              will impose on the server. This can be one of:
 *	              * SSL_VERIFY_NONE (0): the server will not be verified in any way.
 *	              * SSL_VERIFY_PEER (1): the server certificate will be verified
 *	                and the connection aborted if the verification fails.
 *	              The default and recommended value is SSL_VERIFY_PEER. Using
 *	              SSL_VERIFY_NONE provides no security.
 *	tls_version - the version of the SSL/TLS protocol to use as a string. If NULL,
 *	              the default value is used. The default value and the
 *	              available values depend on the version of openssl that the
 *	              library was compiled against. For openssl >= 1.0.1, the
 *	              available options are tlsv1.2, tlsv1.1 and tlsv1, with tlv1.2
 *	              as the default. For openssl < 1.0.1, only tlsv1 is available.
 *	ciphers -     a string describing the ciphers available for use. See the
 *	              "openssl ciphers" tool for more information. If NULL, the
 *	              default ciphers will be used.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * See Also:
 *	<mosquitto_tls_set>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_tls_opts_set(mosq: Pmosquitto; cert_reqs: cint; const tls_version: pchar; const ciphers: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibTlsOptsSetFunction = function(mosq: Pmosquitto; cert_reqs: cint; const tls_version: pchar; const ciphers: pchar): cint; cdecl;
var
  mosquitto_tls_opts_set: TMosqLibTlsOptsSetFunction;
{$ENDIF}


{*
 * Function: mosquitto_tls_psk_set
 *
 * Configure the client for pre-shared-key based TLS support. Must be called
 * before <mosquitto_connect>.
 *
 * Cannot be used in conjunction with <mosquitto_tls_set>.
 *
 * Parameters:
 *  mosq -     a valid mosquitto instance.
 *  psk -      the pre-shared-key in hex format with no leading "0x".
 *  identity - the identity of this client. May be used as the username
 *             depending on the server settings.
 *	ciphers -  a string describing the PSK ciphers available for use. See the
 *	           "openssl ciphers" tool for more information. If NULL, the
 *	           default ciphers will be used.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *
 * See Also:
 *	<mosquitto_tls_set>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_tls_psk_set(mosq: Pmosquitto; const psk: pchar; const identity: pchar; const ciphers: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibTlsPskSetFunction = function(mosq: Pmosquitto; const psk: pchar; const identity: pchar; const ciphers: pchar): cint; cdecl;
var
  mosquitto_tls_psk_set: TMosqLibTlsPskSetFunction;
{$ENDIF}

{*
 * Function: mosquitto_connect_callback_set
 *
 * Set the connect callback. This is called when the broker sends a CONNACK
 * message in response to a connection.
 *
 * Parameters:
 *  mosq -       a valid mosquitto instance.
 *  on_connect - a callback function in the following form:
 *               void callback(mosq: Pmosquitto, void *obj, int rc)
 *
 * Callback Parameters:
 *  mosq - the mosquitto instance making the callback.
 *  obj - the user data provided in <mosquitto_new>
 *  rc -  the return code of the connection response, one of:
 *
 * * 0 - success
 * * 1 - connection refused (unacceptable protocol version)
 * * 2 - connection refused (identifier rejected)
 * * 3 - connection refused (broker unavailable)
 * * 4-255 - reserved for future use
 *}
type
    Ton_connect_callback = procedure(mosq: Pmosquitto; obj: pointer; rc: cint); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_connect_callback_set(mosq: Pmosquitto; on_connect: Ton_connect_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnectCallbackSetProcedure = procedure(mosq: Pmosquitto; on_connect: Ton_connect_callback); cdecl;
var
  mosquitto_connect_callback_set: TMosqLibConnectCallbackSetProcedure;
{$ENDIF}



{*
 * Function: mosquitto_connect_with_flags_callback_set
 *
 * Set the connect callback. This is called when the broker sends a CONNACK
 * message in response to a connection.
 *
 * Parameters:
 *  mosq -       a valid mosquitto instance.
 *  on_connect - a callback function in the following form:
 *               void callback(struct mosquitto *mosq, void *obj, int rc)
 *
 * Callback Parameters:
 *  mosq - the mosquitto instance making the callback.
 *  obj - the user data provided in <mosquitto_new>
 *  rc -  the return code of the connection response, one of:
 *  flags - the connect flags.
 *
 * * 0 - success
 * * 1 - connection refused (unacceptable protocol version)
 * * 2 - connection refused (identifier rejected)
 * * 3 - connection refused (broker unavailable)
 * * 4-255 - reserved for future use
 *}
type
    Ton_connect_with_flags_callback = procedure(mosq: Pmosquitto; obj: pointer; _unknown1: cint; _unknown2: cint); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_connect_with_flags_callback_set(mosq: Pmosquitto; on_connect: Ton_connect_with_flags_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnectWithFlagsCallbackSetProcedure = procedure(mosq: Pmosquitto; on_connect: Ton_connect_with_flags_callback); cdecl;
var
  mosquitto_connect_with_flags_callback_set: TMosqLibConnectWithFlagsCallbackSetProcedure;
{$ENDIF}


{*
 * Function: mosquitto_disconnect_callback_set
 *
 * Set the disconnect callback. This is called when the broker has received the
 * DISCONNECT command and has disconnected the client.
 *
 * Parameters:
 *  mosq -          a valid mosquitto instance.
 *  on_disconnect - a callback function in the following form:
 *                  void callback(mosq: Pmosquitto, void *obj)
 *
 * Callback Parameters:
 *  mosq - the mosquitto instance making the callback.
 *  obj -  the user data provided in <mosquitto_new>
 *  rc -   integer value indicating the reason for the disconnect. A value of 0
 *         means the client has called <mosquitto_disconnect>. Any other value
 *         indicates that the disconnect is unexpected.
 *}
type
    Ton_disconnect_callback = procedure(mosq: Pmosquitto; obj: pointer; rc: cint); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_disconnect_callback_set(mosq: Pmosquitto; on_disconnect: Ton_disconnect_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibDisconnectCallbackSetProcedure = procedure(mosq: Pmosquitto; on_disconnect: Ton_disconnect_callback); cdecl;
var
  mosquitto_disconnect_callback_set: TMosqLibDisconnectCallbackSetProcedure;
{$ENDIF}


{*
 * Function: mosquitto_publish_callback_set
 *
 * Set the publish callback. This is called when a message initiated with
 * <mosquitto_publish> has been sent to the broker successfully.
 *
 * Parameters:
 *  mosq -       a valid mosquitto instance.
 *  on_publish - a callback function in the following form:
 *               void callback(mosq: Pmosquitto, void *obj, int mid)
 *
 * Callback Parameters:
 *  mosq - the mosquitto instance making the callback.
 *  obj -  the user data provided in <mosquitto_new>
 *  mid -  the message id of the sent message.
 *}
type
    Ton_publish_callback = procedure(mosq: Pmosquitto; obj: pointer; rc: cint); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_publish_callback_set(mosq: Pmosquitto; on_publish: Ton_publish_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibPublishCallbackSetProcedure = procedure(mosq: Pmosquitto; on_publish: Ton_publish_callback); cdecl;
var
  mosquitto_publish_callback_set: TMosqLibPublishCallbackSetProcedure;
{$ENDIF}

{*
 * Function: mosquitto_message_callback_set
 *
 * Set the message callback. This is called when a message is received from the
 * broker.
 *
 * Parameters:
 *  mosq -       a valid mosquitto instance.
 *  on_message - a callback function in the following form:
 *               void callback(mosq: Pmosquitto, void *obj, const struct mosquitto_message *message)
 *
 * Callback Parameters:
 *  mosq -    the mosquitto instance making the callback.
 *  obj -     the user data provided in <mosquitto_new>
 *  message - the message data. This variable and associated memory will be
 *            freed by the library after the callback completes. The client
 *            should make copies of any of the data it requires.
 *
 * See Also:
 * 	<mosquitto_message_copy>
 *}
type
    Ton_message_callback = procedure(mosq: Pmosquitto; obj: pointer; const message: Pmosquitto_message); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_message_callback_set(mosq: Pmosquitto; on_message: Ton_message_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibMessageCallbackSetProcedure = procedure(mosq: Pmosquitto; on_message: Ton_message_callback); cdecl;
var
  mosquitto_message_callback_set: TMosqLibMessageCallbackSetProcedure;
{$ENDIF}

{*
 * Function: mosquitto_subscribe_callback_set
 *
 * Set the subscribe callback. This is called when the broker responds to a
 * subscription request.
 *
 * Parameters:
 *  mosq -         a valid mosquitto instance.
 *  on_subscribe - a callback function in the following form:
 *                 void callback(mosq: Pmosquitto, void *obj, int mid, int qos_count, const int *granted_qos)
 *
 * Callback Parameters:
 *  mosq -        the mosquitto instance making the callback.
 *  obj -         the user data provided in <mosquitto_new>
 *  mid -         the message id of the subscribe message.
 *  qos_count -   the number of granted subscriptions (size of granted_qos).
 *  granted_qos - an array of integers indicating the granted QoS for each of
 *                the subscriptions.
 *}
type
    Ton_subscribe_callback = procedure(mosq: Pmosquitto; obj: pointer; mid: cint; qos_count: cint; const granted_qos: pcint); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_subscribe_callback_set(mosq: Pmosquitto; on_subscribe: Ton_subscribe_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubscribeCallbackSetProcedure = procedure(mosq: Pmosquitto; on_subscribe: Ton_subscribe_callback); cdecl;
var
  mosquitto_subscribe_callback_set: TMosqLibSubscribeCallbackSetProcedure;
{$ENDIF}


{*
 * Function: mosquitto_unsubscribe_callback_set
 *
 * Set the unsubscribe callback. This is called when the broker responds to a
 * unsubscription request.
 *
 * Parameters:
 *  mosq -           a valid mosquitto instance.
 *  on_unsubscribe - a callback function in the following form:
 *                   void callback(mosq: Pmosquitto, void *obj, int mid)
 *
 * Callback Parameters:
 *  mosq - the mosquitto instance making the callback.
 *  obj -  the user data provided in <mosquitto_new>
 *  mid -  the message id of the unsubscribe message.
 *}
type
    Ton_unsubscribe_callback = procedure(mosq: Pmosquitto; obj: pointer; mid: cint); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_unsubscribe_callback_set(mosq: Pmosquitto; on_unsubscribe: Ton_unsubscribe_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibUnsubscribeCallbackSetProcedure = procedure(mosq: Pmosquitto; on_unsubscribe: Ton_unsubscribe_callback); cdecl;
var
  mosquitto_unsubscribe_callback_set: TMosqLibUnsubscribeCallbackSetProcedure;
{$ENDIF}


{*
 * Function: mosquitto_log_callback_set
 *
 * Set the logging callback. This should be used if you want event logging
 * information from the client library.
 *
 *  mosq -   a valid mosquitto instance.
 *  on_log - a callback function in the following form:
 *           void callback(mosq: Pmosquitto, void *obj, int level, const char *str)
 *
 * Callback Parameters:
 *  mosq -  the mosquitto instance making the callback.
 *  obj -   the user data provided in <mosquitto_new>
 *  level - the log message level from the values:
 *	        MOSQ_LOG_INFO
 *	        MOSQ_LOG_NOTICE
 *	        MOSQ_LOG_WARNING
 *	        MOSQ_LOG_ERR
 *	        MOSQ_LOG_DEBUG
 *	str -   the message string.
 *}
type
    Ton_log_callback = procedure(mosq: Pmosquitto; obj: pointer; level: cint; const str: pchar); cdecl;

{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_log_callback_set(mosq: Pmosquitto; on_log: Ton_log_callback); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibLogCallbackSetProcedure = procedure(mosq: Pmosquitto; on_log: Ton_log_callback); cdecl;
var
  mosquitto_log_callback_set: TMosqLibLogCallbackSetProcedure;
{$ENDIF}

{*
 * Function: mosquitto_reconnect_delay_set
 *
 * Control the behaviour of the client when it has unexpectedly disconnected in
 * <mosquitto_loop_forever> or after <mosquitto_loop_start>. The default
 * behaviour if this function is not used is to repeatedly attempt to reconnect
 * with a delay of 1 second until the connection succeeds.
 *
 * Use reconnect_delay parameter to change the delay between successive
 * reconnection attempts. You may also enable exponential backoff of the time
 * between reconnections by setting reconnect_exponential_backoff to true and
 * set an upper bound on the delay with reconnect_delay_max.
 *
 * Example 1:
 *	delay=2, delay_max=10, exponential_backoff=False
 *	Delays would be: 2, 4, 6, 8, 10, 10, ...
 *
 * Example 2:
 *	delay=3, delay_max=30, exponential_backoff=True
 *	Delays would be: 3, 6, 12, 24, 30, 30, ...
 *
 * Parameters:
 *  mosq -                          a valid mosquitto instance.
 *  reconnect_delay -               the number of seconds to wait between
 *                                  reconnects.
 *  reconnect_delay_max -           the maximum number of seconds to wait
 *                                  between reconnects.
 *  reconnect_exponential_backoff - use exponential backoff between
 *                                  reconnect attempts. Set to true to enable
 *                                  exponential backoff.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_reconnect_delay_set(mosq: Pmosquitto; reconnect_delay: cuint; reconnect_delay_max: cuint; reconnect_exponential_backoff: cbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibReconnectDelaySetFunction = function(mosq: Pmosquitto; reconnect_delay: cuint; reconnect_delay_max: cuint; reconnect_exponential_backoff: cbool): cint; cdecl;
var
  mosquitto_reconnect_delay_set: TMosqLibReconnectDelaySetFunction;
{$ENDIF}


{*
 * Function: mosquitto_max_inflight_messages_set
 *
 * Set the number of QoS 1 and 2 messages that can be "in flight" at one time.
 * An in flight message is part way through its delivery flow. Attempts to send
 * further messages with <mosquitto_publish> will result in the messages being
 * queued until the number of in flight messages reduces.
 *
 * A higher number here results in greater message throughput, but if set
 * higher than the maximum in flight messages on the broker may lead to
 * delays in the messages being acknowledged.
 *
 * Set to 0 for no maximum.
 *
 * Parameters:
 *  mosq -                  a valid mosquitto instance.
 *  max_inflight_messages - the maximum number of inflight messages. Defaults
 *                          to 20.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success.
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_max_inflight_messages_set(mosq: Pmosquitto; max_inflight_messages: cuint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibMaxInflightMessagesSetFunction = function(mosq: Pmosquitto; max_inflight_messages: cuint): cint; cdecl;
var
  mosquitto_max_inflight_messages_set: TMosqLibMaxInflightMessagesSetFunction;
{$ENDIF}

{
 *
 * Function: mosquitto_message_retry_set
 *
 * This function now has no effect.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_message_retry_set(mosq: Pmosquitto; message_retry: cuint); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibMessageRetrySetProcedure = procedure(mosq: Pmosquitto; message_retry: cuint); cdecl;
var
  mosquitto_message_retry_set: TMosqLibMessageRetrySetProcedure;
{$ENDIF}


{*
 * Function: mosquitto_user_data_set
 *
 * When <mosquitto_new> is called, the pointer given as the "obj" parameter
 * will be passed to the callbacks as user data. The <mosquitto_user_data_set>
 * function allows this obj parameter to be updated at any time. This function
 * will not modify the memory pointed to by the current user data pointer. If
 * it is dynamically allocated memory you must free it yourself.
 *
 * Parameters:
 *  mosq - a valid mosquitto instance.
 * 	obj -  A user pointer that will be passed as an argument to any callbacks
 * 	       that are specified.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
procedure mosquitto_user_data_set(mosq: Pmosquitto; obj: pointer); cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibUserDataSetProcedure = procedure(mosq: Pmosquitto; obj: pointer); cdecl;
var
  mosquitto_user_data_set: TMosqLibUserDataSetProcedure;
{$ENDIF}


{* =============================================================================
 *
 * Section: SOCKS5 proxy functions
 *
 * =============================================================================
 *}

{*
 * Function: mosquitto_socks5_set
 *
 * Configure the client to use a SOCKS5 proxy when connecting. Must be called
 * before connecting. "None" and "username/password" authentication is
 * supported.
 *
 * Parameters:
 *   mosq - a valid mosquitto instance.
 *   host - the SOCKS5 proxy host to connect to.
 *   port - the SOCKS5 proxy port to use.
 *   username - if not NULL, use this username when authenticating with the proxy.
 *   password - if not NULL and username is not NULL, use this password when
 *              authenticating with the proxy.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_socks5_set(mosq: Pmosquitto; const host: pchar; port: cint; const username: pchar; const password: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSocks5SetFunction = function (mosq: Pmosquitto; const host: pchar; port: cint; const username: pchar; const password: pchar): cint; cdecl;
var
  mosquitto_socks5_set: TMosqLibSocks5SetFunction;
{$ENDIF}

{* =============================================================================
 *
 * Section: Utility functions
 *
 * =============================================================================
 *}

{*
 * Function: mosquitto_strerror
 *
 * Call to obtain a const string description of a mosquitto error number.
 *
 * Parameters:
 *	mosq_errno - a mosquitto error number.
 *
 * Returns:
 *	A constant string describing the error.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_strerror(mosq_errno: cint): pchar; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibStrerrorFunction = function(mosq_errno: cint): pchar; cdecl;
var
  mosquitto_strerror: TMosqLibStrerrorFunction;
{$ENDIF}


{*
 * Function: mosquitto_connack_string
 *
 * Call to obtain a const string description of an MQTT connection result.
 *
 * Parameters:
 *	connack_code - an MQTT connection result.
 *
 * Returns:
 *	A constant string describing the result.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_connack_string(connack_code: cint): pchar; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibConnackStringFunction = function(connack_code: cint): pchar; cdecl;
var
  mosquitto_connack_string: TMosqLibConnackStringFunction;
{$ENDIF}

{*
 * Function: mosquitto_sub_topic_tokenise
 *
 * Tokenise a topic or subscription string into an array of strings
 * representing the topic hierarchy.
 *
 * For example:
 *
 * subtopic: "a/deep/topic/hierarchy"
 *
 * Would result in:
 *
 * topics[0] = "a"
 * topics[1] = "deep"
 * topics[2] = "topic"
 * topics[3] = "hierarchy"
 *
 * and:
 *
 * subtopic: "/a/deep/topic/hierarchy/"
 *
 * Would result in:
 *
 * topics[0] = NULL
 * topics[1] = "a"
 * topics[2] = "deep"
 * topics[3] = "topic"
 * topics[4] = "hierarchy"
 *
 * Parameters:
 *	subtopic - the subscription/topic to tokenise
 *	topics -   a pointer to store the array of strings
 *	count -    an int pointer to store the number of items in the topics array.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS -        on success
 * 	MOSQ_ERR_NOMEM -          if an out of memory condition occurred.
 * 	MOSQ_ERR_MALFORMED_UTF8 - if the topic is not valid UTF-8
 *
 * Example:
 *
 * > char **topics;
 * > int topic_count;
 * > int i;
 * >
 * > mosquitto_sub_topic_tokenise("$SYS/broker/uptime", &topics, &topic_count);
 * >
 * > for(i=0; i<token_count; i++)(
 * >     printf("%d: %s\n", i, topics[i]);
 * > )
 *
 * See Also:
 *	<mosquitto_sub_topic_tokens_free>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_sub_topic_tokenise(const subtopic: pchar; var topics: ppchar; count: pcint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubTopicTokeniseFunction = function(const subtopic: pchar; var topics: ppchar; count: pcint): cint; cdecl;
var
  mosquitto_sub_topic_tokenise: TMosqLibSubTopicTokeniseFunction;
{$ENDIF}

{*
 * Function: mosquitto_sub_topic_tokens_free
 *
 * Free memory that was allocated in <mosquitto_sub_topic_tokenise>.
 *
 * Parameters:
 *	topics - pointer to string array.
 *	count - count of items in string array.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 *
 * See Also:
 *	<mosquitto_sub_topic_tokenise>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_sub_topic_tokens_free(var topics: ppchar; count: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubTopicTokensFreeFunction = function(var topics: ppchar; count: cint): cint; cdecl;
var
  mosquitto_sub_topic_tokens_free: TMosqLibSubTopicTokensFreeFunction;
{$ENDIF}
{*
 * Function: mosquitto_topic_matches_sub
 * Function: mosquitto_topic_matches_sub2
 *
 * Check whether a topic matches a subscription.
 *
 * For example:
 *
 * foo/bar would match the subscription foo/# or +/bar
 * non/matching would not match the subscription non/+/+
 *
 * Parameters:
 *	sub - subscription string to check topic against.
 *	sublen - length in bytes of sub string
 *	topic - topic to check.
 *	topiclen - length in bytes of topic string
 *	result - bool pointer to hold result. Will be set to true if the topic
 *	         matches the subscription.
 *
 * Returns:
 *	MOSQ_ERR_SUCCESS - on success
 * 	MOSQ_ERR_INVAL -   if the input parameters were invalid.
 * 	MOSQ_ERR_NOMEM -   if an out of memory condition occurred.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_topic_matches_sub(const sub: pchar; const topic: pchar; result: pcbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibTopicMatchesSubFunction = function(const sub: pchar; const topic: pchar; result: pcbool): cint; cdecl;
var
  mosquitto_topic_matches_sub:  TMosqLibTopicMatchesSubFunction;
{$ENDIF}

{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_topic_matches_sub2(const sub: pchar; sublen: csize_t; const topic: pchar; topiclen: csize_t; result: pcbool): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibTopicMatchesSub2Function = function(const sub: pchar; sublen: csize_t; const topic: pchar; topiclen: csize_t; result: pcbool): cint; cdecl;
var
  mosquitto_topic_matches_sub2:  TMosqLibTopicMatchesSub2Function;
{$ENDIF}


{*
 * Function: mosquitto_pub_topic_check
 *
 * Check whether a topic to be used for publishing is valid.
 *
 * This searches for + or # in a topic and checks its length.
 *
 * This check is already carried out in <mosquitto_publish> and
 * <mosquitto_will_set>, there is no need to call it directly before them. It
 * may be useful if you wish to check the validity of a topic in advance of
 * making a connection for example.
 *
 * Parameters:
 *   topic - the topic to check
 *   topiclen - length of the topic in bytes
 *
 * Returns:
 *   MOSQ_ERR_SUCCESS -        for a valid topic
 *   MOSQ_ERR_INVAL -          if the topic contains a + or a #, or if it is too long.
 * 	 MOSQ_ERR_MALFORMED_UTF8 - if sub or topic is not valid UTF-8
 *
 * See Also:
 *   <mosquitto_sub_topic_check>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_pub_topic_check(const topic: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
 TMosqLibPubTopicCheckFunction = function(const topic: pchar): cint; cdecl;
var
 mosquitto_pub_topic_check: TMosqLibPubTopicCheckFunction;
{$ENDIF}

{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_pub_topic_check2(const topic: pchar; topiclen: csize_t): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibPubTopicCheck2Function = function(const topic: pchar; topiclen: csize_t): cint; cdecl;
var
  mosquitto_pub_topic_check2: TMosqLibPubTopicCheck2Function;
{$ENDIF}

{*
 * Function: mosquitto_sub_topic_check
 *
 * Check whether a topic to be used for subscribing is valid.
 *
 * This searches for + or # in a topic and checks that they aren't in invalid
 * positions, such as with foo/#/bar, foo/+bar or foo/bar#, and checks its
 * length.
 *
 * This check is already carried out in <mosquitto_subscribe> and
 * <mosquitto_unsubscribe>, there is no need to call it directly before them.
 * It may be useful if you wish to check the validity of a topic in advance of
 * making a connection for example.
 *
 * Parameters:
 *   topic - the topic to check
 *   topiclen - the length in bytes of the topic
 *
 * Returns:
 *   MOSQ_ERR_SUCCESS -        for a valid topic
 *   MOSQ_ERR_INVAL -          if the topic contains a + or a # that is in an
 *                             invalid position, or if it is too long.
 * 	 MOSQ_ERR_MALFORMED_UTF8 - if topic is not valid UTF-8
 *
 * See Also:
 *   <mosquitto_sub_topic_check>
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_sub_topic_check(const topic: pchar): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
 TMosqLibSubTopicCheckFunction = function(const topic: pchar): cint; cdecl;
var
 mosquitto_sub_topic_check: TMosqLibSubTopicCheckFunction;
{$ENDIF}

{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_sub_topic_check2(const topic: pchar; topiclen: csize_t): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubTopicCheck2Function = function(const topic: pchar; topiclen: csize_t): cint; cdecl;
var
  mosquitto_sub_topic_check2: TMosqLibSubTopicCheck2Function;
{$ENDIF}



type
    Plibmosquitto_will = ^Tlibmosquitto_will;
    Tlibmosquitto_will = record
        topic: pchar;
        payload: pointer;
        payloadlen: cint;
        qos: cint;
        retain: cbool;
    end;


type
    Plibmosquitto_auth = ^Tlibmosquitto_auth;
    Tlibmosquitto_auth = record
        username: pchar;
        password: pchar;
    end;

type
    Ttls_pw_callback = function(buf: pchar; size: cint; rwflag: cint; userdata: pointer): cint; cdecl;

type
    Plibmosquitto_tls = ^Tlibmosquitto_tls;
    Tlibmosquitto_tls = record
        cafile: pchar;
        capath: pchar;
        certfile: pchar;
        keyfile: pchar;
        ciphers: pchar;
        tls_version: pchar;
        pw_callback: Ttls_pw_callback;
        cert_reqs: cint;
    end;

{*
 * Function: mosquitto_subscribe_simple
 *
 * Helper function to make subscribing to a topic and retrieving some messages
 * very straightforward.
 *
 * This connects to a broker, subscribes to a topic, waits for msg_count
 * messages to be received, then returns after disconnecting cleanly.
 *
 * Parameters:
 *   messages - pointer to a "struct mosquitto_message *". The received
 *              messages will be returned here. On error, this will be set to
 *              NULL.
 *   msg_count - the number of messages to retrieve.
 *   want_retained - if set to true, stale retained messages will be treated as
 *                   normal messages with regards to msg_count. If set to
 *                   false, they will be ignored.
 *   topic - the subscription topic to use (wildcards are allowed).
 *   qos - the qos to use for the subscription.
 *   host - the broker to connect to.
 *   port - the network port the broker is listening on.
 *   client_id - the client id to use, or NULL if a random client id should be
 *               generated.
 *   keepalive - the MQTT keepalive value.
 *   clean_session - the MQTT clean session flag.
 *   username - the username string, or NULL for no username authentication.
 *   password - the password string, or NULL for an empty password.
 *   will - a libmosquitto_will struct containing will information, or NULL for
 *          no will.
 *   tls - a libmosquitto_tls struct containing TLS related parameters, or NULL
 *         for no use of TLS.
 *
 *
 * Returns:
 *   MOSQ_ERR_SUCCESS - on success
 *   >0 - on error.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_subscribe_simple(messages: PPmosquitto_message;
                                    msg_count: cint;
                                    want_retained: cbool;
                                    const topic: pchar;
                                    qos: cint;
                                    const host: pchar;
                                    port: cint;
                                    const client_id: pchar;
                                    keepalive: cint;
                                    clean_session: cbool;
                                    const username: pchar;
                                    const password: pchar;
                                    const will: Plibmosquitto_will;
                                    const tls: Plibmosquitto_tls): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubscribeSimpleFunction = function(messages: PPmosquitto_message;
                                      msg_count: cint;
                                      want_retained: cbool;
                                      const topic: pchar;
                                      qos: cint;
                                      const host: pchar;
                                      port: cint;
                                      const client_id: pchar;
                                      keepalive: cint;
                                      clean_session: cbool;
                                      const username: pchar;
                                      const password: pchar;
                                      const will: Plibmosquitto_will;
                                      const tls: Plibmosquitto_tls): cint; cdecl;
var
   mosquitto_subscribe_simple: TMosqLibSubscribeSimpleFunction;
{$ENDIF}


{*
 * Function: mosquitto_subscribe_callback
 *
 * Helper function to make subscribing to a topic and processing some messages
 * very straightforward.
 *
 * This connects to a broker, subscribes to a topic, then passes received
 * messages to a user provided callback. If the callback returns a 1, it then
 * disconnects cleanly and returns.
 *
 * Parameters:
 *   callback - a callback function in the following form:
 *              int callback(struct mosquitto *mosq, void *obj, const struct mosquitto_message *message)
 *              Note that this is the same as the normal on_message callback,
 *              except that it returns an int.
 *   userdata - user provided pointer that will be passed to the callback.
 *   topic - the subscription topic to use (wildcards are allowed).
 *   qos - the qos to use for the subscription.
 *   host - the broker to connect to.
 *   port - the network port the broker is listening on.
 *   client_id - the client id to use, or NULL if a random client id should be
 *               generated.
 *   keepalive - the MQTT keepalive value.
 *   clean_session - the MQTT clean session flag.
 *   username - the username string, or NULL for no username authentication.
 *   password - the password string, or NULL for an empty password.
 *   will - a libmosquitto_will struct containing will information, or NULL for
 *          no will.
 *   tls - a libmosquitto_tls struct containing TLS related parameters, or NULL
 *         for no use of TLS.
 *
 *
 * Returns:
 *   MOSQ_ERR_SUCCESS - on success
 *   >0 - on error.
 *}

{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_subscribe_callback(callback: Ton_message_callback;
                                      userdata: pointer;
                                      const topic: pchar;
                                      qos: cint;
                                      const host: pchar;
                                      port: cint;
                                      const client_id: pchar;
                                      keepalive: cint;
                                      clean_session: cbool;
                                      const username: pchar;
                                      const password: pchar;
                                      const will: Plibmosquitto_will;
                                      const tls: Plibmosquitto_tls): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibSubscribeCallbackFunction = function(callback: Ton_message_callback;
                                      userdata: pointer;
                                      const topic: pchar;
                                      qos: cint;
                                      const host: pchar;
                                      port: cint;
                                      const client_id: pchar;
                                      keepalive: cint;
                                      clean_session: cbool;
                                      const username: pchar;
                                      const password: pchar;
                                      const will: Plibmosquitto_will;
                                      const tls: Plibmosquitto_tls): cint; cdecl;
var
  mosquitto_subscribe_callback:  TMosqLibSubscribeCallbackFunction;
{$ENDIF}

//
{*
 * Function: mosquitto_validate_utf8
 *
 * Helper function to validate whether a UTF-8 string is valid, according to
 * the UTF-8 spec and the MQTT additions.
 *
 * Parameters:
 *   str - a string to check
 *   len - the length of the string in bytes
 *
 * Returns:
 *   MOSQ_ERR_SUCCESS -        on success
 *   MOSQ_ERR_INVAL -          if str is NULL or len<0 or len>65536
 *   MOSQ_ERR_MALFORMED_UTF8 - if str is not valid UTF-8
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_validate_utf8(const str: pchar; len: cint): cint; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibValidateUtf8Function = function(const str: pchar; len: cint): cint; cdecl;
var
  mosquitto_validate_utf8: TMosqLibValidateUtf8Function;
{$ENDIF}

{* Function: mosquitto_userdata
 *
 * Retrieve the "userdata" variable for a mosquitto client.
 *
 * Parameters:
 * 	mosq - a valid mosquitto instance.
 *
 * Returns:
 *	A pointer to the userdata member variable.
 *}
{$IFNDEF DYNAMIC_MOSQLIB}
function mosquitto_userdata(mosq: Pmosquitto): pointer; cdecl; external libmosq_NAME;
{$ELSE}
Type
  TMosqLibUserdataFunction = function(mosq: Pmosquitto): pointer; cdecl;
var
  mosquitto_userdata: TMosqLibUserdataFunction;
{$ENDIF}


implementation

{$IFNDEF DYNAMIC_MOSQLIB}

function mosquitto_lib_loaded(): boolean;
begin
  mosquitto_lib_loaded := true;
end;

{$ELSE}

var
  lib: TLibHandle;

function mosquitto_lib_loaded(): boolean;
begin
  mosquitto_lib_loaded := lib <> NilHandle
end;


(*
function GetLibProc(var aPointer; const name: string): boolean;
begin
  try
    pointer(aPointer) := GetProcedureAddress(lib, name);
    result := assigned(pointer(aPointer));
  except
    result := false;
  end;
  if not result then begin
    if unloadLibrary(lib) then
      lib := NilHandle;
  end;
end;
*)

function GetLibProc(var aPointer; const name: string): boolean;
begin
  pointer(aPointer) := GetProcedureAddress(lib, name);
  if pointer(aPointer) <> nil then
    GetLibProc := true
  else begin
    unloadLibrary(lib);
    lib := NilHandle;
    GetLibProc := false;
  end;
end;

initialization
  lib := SafeLoadLibrary(libmosq_NAME);
  if lib <> NilHandle then begin
    if not GetLibProc(mosquitto_lib_version, 'mosquitto_lib_version') then exit;
    if not GetLibProc(mosquitto_lib_init, 'mosquitto_lib_init') then exit;
    if not GetLibProc(mosquitto_lib_cleanup, 'mosquitto_lib_cleanup') then exit;
    if not GetLibProc(mosquitto_new, 'mosquitto_new') then exit;
    if not GetLibProc(mosquitto_destroy, 'mosquitto_destroy') then exit;
    if not GetLibProc(mosquitto_reinitialise, 'mosquitto_reinitialise') then exit;
    if not GetLibProc(mosquitto_will_set, 'mosquitto_will_set') then exit;
    if not GetLibProc(mosquitto_will_clear, 'mosquitto_will_clear') then exit;
    if not GetLibProc(mosquitto_username_pw_set, 'mosquitto_username_pw_set') then exit;
    if not GetLibProc(mosquitto_connect, 'mosquitto_connect') then exit;
    if not GetLibProc(mosquitto_connect_bind, 'mosquitto_connect_bind') then exit;
    if not GetLibProc(mosquitto_connect_async, 'mosquitto_connect_async') then exit;
    if not GetLibProc(mosquitto_connect_bind_async, 'mosquitto_connect_bind_async') then exit;
    if not GetLibProc(mosquitto_connect_srv, 'mosquitto_connect_srv') then exit;
    if not GetLibProc(mosquitto_reconnect, 'mosquitto_reconnect') then exit;
    if not GetLibProc(mosquitto_reconnect_async, 'mosquitto_reconnect_async') then exit;
    if not GetLibProc(mosquitto_disconnect, 'mosquitto_disconnect') then exit;
    if not GetLibProc(mosquitto_publish, 'mosquitto_publish') then exit;
    if not GetLibProc(mosquitto_subscribe, 'mosquitto_subscribe') then exit;
    if not GetLibProc(mosquitto_unsubscribe, 'mosquitto_unsubscribe') then exit;
    if not GetLibProc(mosquitto_message_copy, 'mosquitto_message_copy') then exit;
    if not GetLibProc(mosquitto_message_free, 'mosquitto_message_free') then exit;
    if not GetLibProc(mosquitto_message_free_contents, 'mosquitto_message_free_contents') then exit;
    if not GetLibProc(mosquitto_loop, 'mosquitto_loop') then exit;
    if not GetLibProc(mosquitto_loop_forever, 'mosquitto_loop_forever') then exit;
    if not GetLibProc(mosquitto_loop_start, 'mosquitto_loop_start') then exit;
    if not GetLibProc(mosquitto_loop_stop, 'mosquitto_loop_stop') then exit;
    if not GetLibProc(mosquitto_loop_read, 'mosquitto_loop_read') then exit;
    if not GetLibProc(mosquitto_loop_write, 'mosquitto_loop_write') then exit;
    if not GetLibProc(mosquitto_loop_misc, 'mosquitto_loop_misc') then exit;
    if not GetLibProc(mosquitto_socket, 'mosquitto_socket') then exit;
    if not GetLibProc(mosquitto_want_write, 'mosquitto_want_write') then exit;
    if not GetLibProc(mosquitto_opts_set, 'mosquitto_opts_set') then exit;
    if not GetLibProc(mosquitto_threaded_set, 'mosquitto_threaded_set') then exit;
    if not GetLibProc(mosquitto_tls_set, 'mosquitto_tls_set') then exit;
    if not GetLibProc(mosquitto_tls_insecure_set, 'mosquitto_tls_insecure_set') then exit;
    if not GetLibProc(mosquitto_tls_opts_set, 'mosquitto_tls_opts_set') then exit;
    if not GetLibProc(mosquitto_tls_psk_set, 'mosquitto_tls_psk_set') then exit;
    if not GetLibProc(mosquitto_connect_callback_set, 'mosquitto_connect_callback_set') then exit;
    if not GetLibProc(mosquitto_connect_with_flags_callback_set, 'mosquitto_connect_with_flags_callback_set') then exit;
    if not GetLibProc(mosquitto_disconnect_callback_set, 'mosquitto_disconnect_callback_set') then exit;
    if not GetLibProc(mosquitto_publish_callback_set, 'mosquitto_publish_callback_set') then exit;
    if not GetLibProc(mosquitto_message_callback_set, 'mosquitto_message_callback_set') then exit;
    if not GetLibProc(mosquitto_subscribe_callback_set, 'mosquitto_subscribe_callback_set') then exit;
    if not GetLibProc(mosquitto_unsubscribe_callback_set, 'mosquitto_unsubscribe_callback_set') then exit;
    if not GetLibProc(mosquitto_log_callback_set, 'mosquitto_log_callback_set') then exit;
    if not GetLibProc(mosquitto_reconnect_delay_set, 'mosquitto_reconnect_delay_set') then exit;
    if not GetLibProc(mosquitto_max_inflight_messages_set, 'mosquitto_max_inflight_messages_set') then exit;
    if not GetLibProc(mosquitto_message_retry_set, 'mosquitto_message_retry_set') then exit;
    if not GetLibProc(mosquitto_user_data_set, 'mosquitto_user_data_set') then exit;
    if not GetLibProc(mosquitto_socks5_set, 'mosquitto_socks5_set') then exit;
    if not GetLibProc(mosquitto_strerror, 'mosquitto_strerror') then exit;
    if not GetLibProc(mosquitto_connack_string, 'mosquitto_connack_string') then exit;
    if not GetLibProc(mosquitto_sub_topic_tokens_free, 'mosquitto_sub_topic_tokens_free') then exit;
    if not GetLibProc(mosquitto_topic_matches_sub, 'mosquitto_topic_matches_sub') then exit;
    if not GetLibProc(mosquitto_topic_matches_sub2, 'mosquitto_topic_matches_sub2') then exit;
    if not GetLibProc(mosquitto_pub_topic_check, 'mosquitto_pub_topic_check') then exit;
    if not GetLibProc(mosquitto_pub_topic_check2, 'mosquitto_pub_topic_check2') then exit;
    if not GetLibProc(mosquitto_sub_topic_check, 'mosquitto_sub_topic_check') then exit;
    if not GetLibProc(mosquitto_sub_topic_check2, 'mosquitto_sub_topic_check2') then exit;
    if not GetLibProc(mosquitto_subscribe_simple, 'mosquitto_subscribe_simple') then exit;
    if not GetLibProc(mosquitto_subscribe_callback, 'mosquitto_subscribe_callback') then exit;
    if not GetLibProc(mosquitto_validate_utf8, 'mosquitto_validate_utf8') then exit;
    if not GetLibProc(mosquitto_userdata, 'mosquitto_userdata') then exit;
  end;
finalization
  if lib <> NilHandle then
    unloadLibrary(lib);
{$ENDIF}
end.
