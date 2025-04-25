#!/bin/bash

sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo sysctl vm.swappiness=60  # 提高交换倾向

# 保护关键进程
echo 'SSHD=1' | sudo tee -a /etc/default/grub
echo 'GRUB_CMDLINE_LINUX="systemd.oom_score_adj=-1000"' | sudo tee -a /etc/default/grub
sudo update-grub