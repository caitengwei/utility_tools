import sys
import subprocess

dns_ip = sys.argv[1]
domain = "icloud.com"

# 使用 dig 命令获取 Apple 香港服务的 IP 地址
dig_command = f"dig @{dns_ip} {domain}"
dig_output = subprocess.check_output(dig_command, shell=True).decode("utf-8")

apple_hk_ip = ""
for line in dig_output.split("\n"):
    if domain in line and "A" in line:
        parts = line.split()
        for part in parts:
            if part.count(".") == 3:  # 判断是否为IPv4地址
                apple_hk_ip = part
                break

if not apple_hk_ip:
    print("无法解析 Apple 香港服务的 IP 地址。")
    sys.exit(1)

# 使用 ping 命令测试延迟
ping_count = 5
ping_command = f"ping -c {ping_count} {apple_hk_ip}"
ping_output = subprocess.check_output(ping_command, shell=True).decode("utf-8")

# 提取平均延迟并输出
avg_latency_line = [line for line in ping_output.split("\n") if "avg" in line][0]
avg_latency = avg_latency_line.split("/")[4]
print(f"平均延迟：{avg_latency} ms")
