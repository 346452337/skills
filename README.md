# Hermes Skills

个人技能仓库，存储自定义的 Hermes Agent 技能。

## 目录结构

```
skills/
└── gao-wechat-download/    # 微信公众号文章下载技能
    ├── SKILL.md            # 技能定义
    ├── scripts/            # 脚本文件
    │   ├── download.sh
    │   ├── cloakbrowser-fetch.mjs
    │   └── self-heal.sh
    └── references/         # 参考文档
        └── wechat-download-research.md
```

## 技能列表

### gao-wechat-download

微信公众号文章下载器，支持:

- **双模式下载**: curl (主) → CloakBrowser (备)
- **验证码绕过**: 两种模式均针对微信反爬优化
- **自我进化**: 失败时自动分析并修复
- **Markdown输出**: YAML frontmatter + 内容 + 图片
- **Git集成**: 自动提交推送

使用方式：发送 `mp.weixin.qq.com` 链接即可触发。

## 使用方法

将此仓库克隆到 Hermes 的技能目录:

```bash
git clone https://github.com/346452337/skills.git ~/.hermes/skills/custom
```

或在 `~/.hermes/config.yaml` 中配置技能路径。

## License

MIT