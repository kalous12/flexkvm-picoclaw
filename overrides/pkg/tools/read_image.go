package tools

import (
	"context"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/sipeed/picoclaw/pkg/config"
)

// ReadImageTool allows the LLM to read and analyze local image files.
// The image is converted to base64 Data URL and returned for vision model processing.
type ReadImageTool struct {
	workspace   string
	restrict    bool
	maxFileSize int
}

func NewReadImageTool(workspace string, restrict bool, maxFileSize int) *ReadImageTool {
	if maxFileSize <= 0 {
		maxFileSize = config.DefaultMaxMediaSize
	}
	return &ReadImageTool{
		workspace:   workspace,
		restrict:    restrict,
		maxFileSize: maxFileSize,
	}
}

func (t *ReadImageTool) Name() string { return "read_image" }
func (t *ReadImageTool) Description() string {
	return "Read an image file and prepare it for vision analysis. Returns the image as base64 Data URL that can be used by the LLM to analyze the image."
}

func (t *ReadImageTool) Parameters() map[string]any {
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"path": map[string]any{
				"type":        "string",
				"description": "Path to the image file. Relative paths are resolved from workspace.",
			},
		},
		"required": []string{"path"},
	}
}

func (t *ReadImageTool) Execute(ctx context.Context, args map[string]any) *ToolResult {
	path, _ := args["path"].(string)
	if strings.TrimSpace(path) == "" {
		return ErrorResult("path is required")
	}

	resolved, err := validatePath(path, t.workspace, t.restrict)
	if err != nil {
		return ErrorResult(fmt.Sprintf("invalid path: %v", err))
	}

	info, err := os.Stat(resolved)
	if err != nil {
		return ErrorResult(fmt.Sprintf("file not found: %v", err))
	}
	if info.IsDir() {
		return ErrorResult("path is a directory, expected an image file")
	}
	if info.Size() > int64(t.maxFileSize) {
		return ErrorResult(fmt.Sprintf(
			"file too large: %d bytes (max %d bytes)",
			info.Size(), t.maxFileSize,
		))
	}

	// Detect MIME type
	mime := detectMediaType(resolved)
	if !strings.HasPrefix(mime, "image/") {
		return ErrorResult(fmt.Sprintf("not an image file: %s", mime))
	}

	// Read and encode to base64
	data, err := os.ReadFile(resolved)
	if err != nil {
		return ErrorResult(fmt.Sprintf("failed to read file: %v", err))
	}

	encoded := base64.StdEncoding.EncodeToString(data)
	dataURL := fmt.Sprintf("data:%s;base64,%s", mime, encoded)

	// Return the Data URL for vision model analysis via Media field
	filename := filepath.Base(resolved)
	prompt := `分析这张远程电脑截图，为后续操作提供精确信息。

## 输出要求

### 1. 界面概览
- 界面类型：（桌面/浏览器/应用/登录/弹窗/文件管理器等）
- 实际分辨率：检测图片实际像素尺寸
- 主窗口：当前活动窗口是什么

### 2. 鼠标状态
- 鼠标指针是否存在？位置在哪里？
- 鼠标悬停的元素是什么

### 3. 可交互元素（按重要性排序）
使用精确坐标，格式：元素名称 | 坐标 | 操作类型 | 描述

示例：
- 确定 | (960,540) | click | 绿色按钮，对话框确认
- 搜索框 | (500,100) | input | 空白，占位符"搜索..."
- 关闭 | (1900,10) | click | 红色X按钮

### 4. 当前焦点
- 哪个元素处于激活/焦点状态？
- 光标在哪个输入框？`

	return &ToolResult{
		ForLLM: fmt.Sprintf("图片 '%s' 已加载。\n\n%s", filename, prompt),
		Media:   []string{dataURL},
		Silent:  false,
	}
}
