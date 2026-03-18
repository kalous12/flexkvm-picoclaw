# flexkvm-picoclaw

Picoclaw AI Agent ARMv7 交叉编译

## 版本

- Picoclaw: v0.2.3

## 编译

```bash
make
```

## 输出

```
out/
└── picoclaw    # 主程序
```

## 工具链

- 目标平台: RV1106 (arm-rockchip830-linux-uclibcgnueabihf)
- 默认工具链前缀: `arm-rockchip830-linux-uclibcgnueabihf-`

## 自定义工具链

```bash
export CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf-
make
```
