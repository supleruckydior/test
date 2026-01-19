#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
简单测试脚本
"""
import sys
import os

print("测试脚本开始执行...")
print(f"Python版本: {sys.version}")
print(f"当前目录: {os.getcwd()}")

file_path = r"C:\Users\Administrator\AppData\Local\seliware-workspace\roblox_account_data.tsv"
print(f"检查文件: {file_path}")
print(f"文件是否存在: {os.path.exists(file_path)}")

if os.path.exists(file_path):
    print(f"文件大小: {os.path.getsize(file_path)} 字节")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            print(f"文件行数: {len(lines)}")
            if len(lines) > 0:
                print(f"第一行: {lines[0][:100]}")
    except Exception as e:
        print(f"读取文件出错: {e}")

input("\n按回车键退出...")



