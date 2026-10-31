# 维护与提交署名

本项目由 [kitty191](https://github.com/kitty191) 主导和审查，Codex 协助实现与检查。

按维护者约定，后续由 Codex 协助完成的本项目提交以维护者为主作者，并附加 Codex 共同作者：

```text
Author: WeiSong Zheng <265797658+kitty191@users.noreply.github.com>

Co-authored-by: Codex <codex@openai.com>
```

维护者使用 GitHub 公开的 noreply 邮箱关联账号，不需要公开私人邮箱。其他参与者保留各自的真实署名。已有历史提交保持原样。

分支提交的署名可在提交详情页查看；合并到默认分支后，GitHub 才会将其计入仓库 Contributors 等统计，统计刷新可能延迟。若使用 squash 合并，请保留主作者与 `Co-authored-by` 尾注。

## Review 与合并

功能更新先提交到功能分支并提供源码 PR，交由 kitty191 审查。只有维护者在当前任务中明确要求合并时，才可以合并到 `main`；授权提交、推送、生成安装包、修复问题或检查通过均不代表同意合并。未经明确授权也不得开启自动合并。

`builds/*` 是独立的安装包下载分支，只有安装包、校验文件与说明，没有与源码相同的提交历史，不应合并到 `main`。发布时应分别提供 APK 下载链接与源码 PR 链接，源码审查使用功能分支的 PR，不使用 `main...builds/*` 的比较页面。
