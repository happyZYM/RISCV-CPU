#!/bin/bash

# 定义需要同步的目录列表
SYNC_DIRS=("fpga" "script" "sim" "testcase" "testspace")

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 获取项目根目录
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "无法创建临时目录" >&2
  exit 1
fi

# 确保退出时删除临时目录
trap "rm -rf '$TEMP_DIR'" EXIT

# 克隆上游仓库
echo "正在克隆上游仓库..."
if ! git clone --depth 1 https://github.com/ACMClassCourse-2023/CPU2024/ "$TEMP_DIR/upstream"; then
  echo "克隆上游仓库失败" >&2
  exit 1
fi

cp "$TEMP_DIR/upstream/README.md" "$PROJECT_ROOT/docs/requirement.md"
cp -r "$TEMP_DIR/upstream/doc" "$PROJECT_ROOT/docs/tutorial"

# 对每个目录进行同步
for dir in "${SYNC_DIRS[@]}"; do
  echo "正在处理 $dir 目录..."
  
  while true; do
    read -p "是否要同步 $dir 目录？ (y)es / (n)o / (d)iff / (c)ancel: " choice
    case "$choice" in
      y|Y)
        echo "正在同步 $dir 目录..."
        rsync -av --update "$TEMP_DIR/upstream/$dir/" "$PROJECT_ROOT/$dir/"
        break
        ;;
      n|N)
        echo "跳过 $dir 目录"
        break
        ;;
      d|D)
        echo "显示 $dir 目录的差异..."
        diff -r "$TEMP_DIR/upstream/$dir" "$PROJECT_ROOT/$dir" || true
        ;;
      c|C)
        echo "取消同步 $dir 目录"
        break
        ;;
      *)
        echo "无效的选择，请重新输入"
        ;;
    esac
  done
done

echo "同步完成"