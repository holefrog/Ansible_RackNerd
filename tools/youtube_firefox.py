#!/usr/bin/env python3
# v2 - 从 Firefox 导出 YouTube cookies 为 Netscape 格式

import sqlite3
import os
import glob
import sys

def find_firefox_profile():
    patterns = [
        "~/.mozilla/firefox/*.default-release/cookies.sqlite",
        "~/.mozilla/firefox/*.default/cookies.sqlite",
        "~/.mozilla/firefox/*/cookies.sqlite",
    ]
    for pattern in patterns:
        results = glob.glob(os.path.expanduser(pattern))
        if results:
            return results[0]
    raise FileNotFoundError("找不到 Firefox cookies.sqlite，请确认 Firefox 已安装且运行过")

def export_cookies(output_path="cookies.txt"):
    db_path = find_firefox_profile()
    print(f"找到 cookies 数据库：{db_path}")
    print("请确认 Firefox 已完全关闭，否则数据库可能被锁定。继续？(y/n): ", end="")
    if input().strip().lower() != "y":
        print("已取消")
        sys.exit(0)

    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT host, path, isSecure, expiry, name, value
            FROM moz_cookies
            WHERE host LIKE '%youtube.com' OR host LIKE '%google.com'
            ORDER BY host, name
        """)
        rows = cursor.fetchall()
        conn.close()
    except sqlite3.OperationalError as e:
        print(f"数据库读取失败：{e}")
        print("请关闭 Firefox 后重试")
        sys.exit(1)

    if not rows:
        print("没有找到 YouTube/Google cookies，请确认已在 Firefox 中登录 YouTube")
        sys.exit(1)

    with open(output_path, "w") as f:
        f.write("# Netscape HTTP Cookie File\n\n")
        for host, path, is_secure, expiry, name, value in rows:
            include_subdomains = "TRUE" if host.startswith(".") else "FALSE"
            secure = "TRUE" if is_secure else "FALSE"
            f.write(f"{host}\t{include_subdomains}\t{path}\t{secure}\t{expiry}\t{name}\t{value}\n")

    print(f"导出完成：{output_path}（共 {len(rows)} 条 cookies）")

if __name__ == "__main__":
    export_cookies()