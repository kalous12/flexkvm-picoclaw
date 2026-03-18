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
	prompt := `请分析这张远程电脑截图。

## 输出要求（必须包含以下信息）

### 1. 界面类型
- 这是什么界面？（桌面/浏览器/应用/登录/文件管理器/设置页面等）
- 屏幕分辨率？（如 1920x1080）

### 2. 详细元素位置（必须给出具体坐标）
使用 "区域: X坐标,Y坐标" 格式描述，屏幕左上角为 (0,0)，右下角为 (1920,1080)

| 元素类型 | 位置坐标 | 描述 |
|---------|---------|------|
| 按钮A | (x,y) | 颜色、标签文字 |
| 输入框 | (x,y) | 占位符/标签 |
| 链接 | (x,y) | 链接文字 |
| 图标 | (x,y) | 功能说明 |
| 菜单项 | (x,y) | 菜单位置层级 |

### 3. 可操作元素总结
按以下格式列出所有可点击/可交互的元素：
- 按钮「确定」：位置 (960,540)，点击需要移动鼠标到该坐标
- 输入框「搜索」：位置 (500,100)，点击后可以输入文字
- 链接「了解更多」：位置 (200,300)

### 4. 下一步操作建议
根据用户需求，建议：1) 需要点击哪个元素 2) 需要输入什么内容 3) 需要滚动页面吗`

	return &ToolResult{
		ForLLM: fmt.Sprintf("图片 '%s' 已加载。\n\n%s", filename, prompt),
		Media:   []string{dataURL},
		Silent:  false,
	}
}
