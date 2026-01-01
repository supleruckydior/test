#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
监控 roblox_account_data.tsv 文件，显示最后1分钟内更新的用户名
按回车键刷新显示
"""

import os
import sys
import time
from datetime import datetime, timedelta

# Windows剪贴板支持
try:
    import pyperclip
    HAS_CLIPBOARD = True
except ImportError:
    HAS_CLIPBOARD = False
    try:
        # 尝试使用 tkinter（Python 标准库）
        import tkinter as tk
        HAS_TKINTER = True
    except ImportError:
        HAS_TKINTER = False

# 文件路径（默认路径，如果不存在则尝试当前目录）
DEFAULT_FILE_PATH = r"C:\Users\Administrator\AppData\Local\seliware-workspace\roblox_account_data.tsv"
FALLBACK_FILE_PATH = "roblox_account_data.tsv"

def parse_timestamp(timestamp_str):
    """解析时间戳字符串为datetime对象"""
    try:
        return datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
    except (ValueError, TypeError):
        return None

def read_tsv_file(file_path):
    """读取TSV文件并返回账号数据列表"""
    if not os.path.exists(file_path):
        return []
    
    accounts = []
    try:
        # 尝试不同的编码
        encodings = ['utf-8', 'utf-8-sig', 'gbk', 'gb18030']
        content = None
        
        for encoding in encodings:
            try:
                with open(file_path, 'r', encoding=encoding) as f:
                    content = f.read()
                break
            except UnicodeDecodeError:
                continue
        
        if content is None:
            return []
        
        lines = content.split('\n')
        
        # 跳过标题行
        if len(lines) < 2:
            return []
        
        # 解析数据行
        for line in lines[1:]:
            line = line.strip()
            if not line:
                continue
            
            parts = line.split('\t')
            if len(parts) >= 4:
                account_name = parts[0]
                herbs = parts[1] if len(parts) > 1 else "0"
                ore = parts[2] if len(parts) > 2 else "0"
                update_time_str = parts[3] if len(parts) > 3 else ""
                guild_name = parts[4] if len(parts) > 4 else ""
                
                update_time = parse_timestamp(update_time_str)
                
                accounts.append({
                    'account': account_name,
                    'herbs': herbs,
                    'ore': ore,
                    'update_time': update_time,
                    'update_time_str': update_time_str,
                    'guild_name': guild_name
                })
    except Exception as e:
        # 在静默模式下不打印错误，由主函数处理
        return []
    
    return accounts

def get_recent_accounts(accounts, minutes=1):
    """获取最后N分钟内更新的账号"""
    if not accounts:
        return []
    
    now = datetime.now()
    time_threshold = now - timedelta(minutes=minutes)
    
    recent_accounts = []
    for acc in accounts:
        if acc['update_time'] and acc['update_time'] >= time_threshold:
            recent_accounts.append(acc)
    
    # 按更新时间倒序排序（最新的在前）
    recent_accounts.sort(key=lambda x: x['update_time'] if x['update_time'] else datetime.min, reverse=True)
    
    return recent_accounts

def clear_screen():
    """清屏（跨平台）"""
    if os.name == 'nt':  # Windows
        os.system('cls')
    else:  # Linux/Mac
        os.system('clear')

def copy_to_clipboard(text):
    """复制文本到剪贴板"""
    try:
        if HAS_CLIPBOARD:
            pyperclip.copy(text)
            return True
        elif HAS_TKINTER:
            root = tk.Tk()
            root.withdraw()  # 隐藏窗口
            root.clipboard_clear()
            root.clipboard_append(text)
            root.update()
            root.destroy()
            return True
        else:
            # Windows 使用 clip 命令
            if os.name == 'nt':
                import subprocess
                process = subprocess.Popen(['clip'], stdin=subprocess.PIPE, close_fds=True)
                process.communicate(input=text.encode('utf-8'))
                return True
    except Exception as e:
        print(f"复制失败: {e}")
        return False
    return False

def display_recent_accounts(recent_accounts, total_accounts, file_path, first_display=False):
    """显示最近更新的账号"""
    if not first_display:
        clear_screen()
    
    print("=" * 80)
    print(f"监控文件: {os.path.basename(file_path)}")
    print(f"文件路径: {file_path[:70]}..." if len(file_path) > 70 else f"文件路径: {file_path}")
    print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"总账号数: {total_accounts}")
    print(f"最后1分钟内更新的账号数: {len(recent_accounts)}")
    print("=" * 80)
    print()
    
    if not recent_accounts:
        print("【暂无数据】最近1分钟内没有账号更新")
        if total_accounts == 0:
            print("【提示】文件中没有账号数据，或文件为空")
        else:
            print(f"【提示】文件中有 {total_accounts} 个账号，但最近1分钟内没有更新")
        print()
        print("按回车键刷新，输入 'q' 或 'quit' 退出")
        return recent_accounts
    
    # 显示账号列表
    print(f"{'序号':<6}{'用户名':<25}{'更新时间':<20}{'草药':<15}{'矿石':<15}{'公会':<20}")
    print("-" * 100)
    
    for idx, acc in enumerate(recent_accounts, 1):
        account_name = acc['account'][:24]  # 限制长度
        update_time = acc['update_time_str']
        herbs = acc['herbs']
        ore = acc['ore']
        guild = acc['guild_name'][:19] if acc['guild_name'] else "无"
        
        print(f"{idx:<6}{account_name:<25}{update_time:<20}{herbs:<15}{ore:<15}{guild:<20}")
    
    print()
    print("-" * 100)
    print("操作说明：")
    print("  - 按回车键刷新")
    print("  - 输入序号（如 1, 2, 3）复制对应的用户名到剪贴板")
    print("  - 输入 'c' 或 'copy' 或 'all' 复制所有显示的用户名（每行一个）")
    print("  - 输入 'q' 或 'quit' 退出")
    
    return recent_accounts

def main():
    """主函数"""
    # 立即输出，确保可以看到
    sys.stdout.write("正在启动监控程序...\n")
    sys.stdout.flush()
    
    # 确定文件路径（优先使用默认路径，如果不存在则尝试当前目录）
    file_path = None
    if os.path.exists(DEFAULT_FILE_PATH):
        file_path = DEFAULT_FILE_PATH
    elif os.path.exists(FALLBACK_FILE_PATH):
        file_path = os.path.abspath(FALLBACK_FILE_PATH)
    else:
        # 尝试查找文件
        file_path = DEFAULT_FILE_PATH
    
    print("正在检查文件...")
    print(f"尝试的文件路径:")
    print(f"  1. {DEFAULT_FILE_PATH}")
    print(f"  2. {os.path.abspath(FALLBACK_FILE_PATH)}")
    print()
    
    if not os.path.exists(file_path):
        print(f"错误：文件不存在！")
        print(f"尝试的路径: {file_path}")
        print(f"当前目录: {os.getcwd()}")
        input("\n按回车键退出...")
        return
    
    print(f"✓ 找到文件: {file_path}")
    try:
        file_size = os.path.getsize(file_path)
        print(f"文件大小: {file_size} 字节")
    except Exception as e:
        print(f"无法获取文件大小: {e}")
    
    print("\n程序运行中，按回车键刷新显示...")
    print("(首次运行会显示所有数据，后续按回车刷新)")
    input("按回车键开始...")  # 等待用户按键，确保看到启动信息
    
    first_display = True
    while True:
        # 读取文件
        try:
            accounts = read_tsv_file(file_path)
        except Exception as e:
            print(f"读取文件时出错: {e}")
            import traceback
            traceback.print_exc()
            input("\n按回车键重试，输入 'q' 退出: ")
            continue
        
        # 检查文件是否被读取成功
        if not os.path.exists(file_path):
            if not first_display:
                clear_screen()
            print("=" * 80)
            print(f"错误：文件不存在！")
            print(f"文件路径: {file_path}")
            print(f"当前目录: {os.getcwd()}")
            print("=" * 80)
            print("\n按回车键重试，输入 'q' 退出")
            try:
                user_input = input().strip().lower()
                if user_input in ['q', 'quit', 'exit']:
                    print("\n程序已退出")
                    break
                continue
            except (EOFError, KeyboardInterrupt):
                print("\n\n程序已退出")
                break
        
        # 获取最近1分钟内更新的账号
        try:
            recent_accounts = get_recent_accounts(accounts, minutes=1)
        except Exception as e:
            print(f"处理数据时出错: {e}")
            import traceback
            traceback.print_exc()
            input("\n按回车键重试...")
            continue
        
        # 显示结果
        try:
            display_recent_accounts(recent_accounts, len(accounts), file_path, first_display)
            first_display = False
        except Exception as e:
            print(f"显示数据时出错: {e}")
            import traceback
            traceback.print_exc()
            input("\n按回车键重试...")
            continue
        
        # 等待用户输入
        try:
            user_input = input("\n请输入操作: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n\n程序已退出")
            break
        
        user_input_lower = user_input.lower()
        
        # 检查是否是退出命令
        if user_input_lower in ['q', 'quit', 'exit']:
            print("\n程序已退出")
            break
        
        # 检查是否是复制所有用户名
        if user_input_lower in ['c', 'copy', 'all']:
            if recent_accounts and len(recent_accounts) > 0:
                # 获取所有用户名，每行一个
                all_accounts = [acc['account'] for acc in recent_accounts]
                all_accounts_text = '\n'.join(all_accounts)
                if copy_to_clipboard(all_accounts_text):
                    print(f"✓ 已复制 {len(all_accounts)} 个用户名到剪贴板（每行一个）")
                    print(f"  用户名列表：")
                    for i, acc in enumerate(all_accounts, 1):
                        print(f"    {i}. {acc}")
                else:
                    print(f"✗ 复制失败")
            else:
                print("✗ 没有可复制的用户名")
            input("\n按回车键继续...")
            continue
        
        # 检查是否是数字（复制单个用户名）
        if user_input.isdigit():
            try:
                index = int(user_input) - 1  # 转换为0-based索引
                if 0 <= index < len(recent_accounts):
                    account_name = recent_accounts[index]['account']
                    if copy_to_clipboard(account_name):
                        print(f"✓ 已复制用户名到剪贴板: {account_name}")
                    else:
                        print(f"✗ 复制失败，用户名: {account_name}")
                else:
                    print(f"✗ 无效的序号，请输入 1-{len(recent_accounts)} 之间的数字")
            except ValueError:
                print("✗ 无效的输入")
            except Exception as e:
                print(f"✗ 复制时出错: {e}")
            # 继续循环，不清屏，让用户看到复制结果
            input("\n按回车键继续...")
            continue
        
        # 如果输入为空或回车，刷新显示
        if not user_input or user_input == '':
            continue

if __name__ == "__main__":
    try:
        # 立即输出，确保脚本开始执行
        sys.stdout.write("脚本开始执行...\n")
        sys.stdout.flush()
        main()
    except KeyboardInterrupt:
        print("\n\n程序被用户中断")
        input("按回车键退出...")
        sys.exit(0)
    except Exception as e:
        import traceback
        print(f"\n发生错误: {e}")
        print("\n详细错误信息:")
        traceback.print_exc()
        input("\n按回车键退出...")
        sys.exit(1)

