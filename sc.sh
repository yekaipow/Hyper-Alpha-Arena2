 counter_file=".commit_counter"
    # 1. 如果文件不存在，初始化为 0
    if [ ! -f "$counter_file" ]; then
        echo 0 > "$counter_file"
    fi
    # 2. 读取当前编号并加 1
     n=$(cat "$counter_file")
    n=$((n + 1))
    # 3. 执行 Git 操作
    git add .
    # 使用格式化后的编号提交
    if git commit -m "修复bug#$n"; then
        # 只有 commit 成功才更新编号文件
        echo $n > "$counter_file"
        
        # 4. 强制推送
        git push -f origin main
    else
        echo "Git commit 失败，编号未增加。"
    fi