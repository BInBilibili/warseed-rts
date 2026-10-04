# GitHub 构建与自动发包

配置入口：[工作流](../.github/workflows/grey-ridge-ci.yml)、[打包脚本](../tools/build_github_package.ps1)。工作项：[WS-MAINT-20261005-001](work_items/WS-MAINT-20261005-001.md)。

日常推送到分支、Pull Request 和手动运行会在Windows执行完整发布门，成功后上传Windows ZIP与SHA-256，Actions产物保留14天。推送`v*`标签会在同一套验证和构建成功后，把该次产物发布到GitHub Releases；失败不会进入发布任务。标签发布不被其他推送取消，日常同分支新推送可取消旧构建。

本项目仍是开发测试版本，自动创建的Release标为**Pre-release**，不修改产品阶段或原维护项完成状态。新包包含终局决战与旧四关；当前仅构建Windows x64，使用debug导出，与既有发布验证相同。自动发包不包含玩家客户端的自动下载或更新。

## 日常提交与下载

```powershell
git add -A
git commit -m "Describe the game changes"
git push origin main
```

打开仓库[Actions](https://github.com/msdest565/warseed-rts/actions)，进入`WARSEED Build and Release`的成功运行，在Artifacts下载`warseed-windows-*`。GitHub会把产物再套一层ZIP，解开后里面的WARSEED ZIP才是完整游戏包。

## 发布版本

确保目标提交已推送并通过验证，再选择一个未使用的标签。以下只是命令示例，不代表本次已发布该版本：

```powershell
git tag -a v0.1.1-test.1 -m "WARSEED Windows playtest"
git push origin v0.1.1-test.1
```

完整门通过后，在[Releases](https://github.com/msdest565/warseed-rts/releases)下载`WARSEED-<tag>-Windows-x64.zip`与对应`.sha256`。已有同名Release会让发布失败，不覆盖旧附件；失败时先查日志，修复后创建新版本标签。分支手动运行只构建，不发布。

解压整个目录并保持EXE、PCK与`data_WARSEED_windows_x86_64`在一起。双击`START_WARSEED.cmd`进入独立试玩会话；主菜单选择“最终决战”。`BUILD_INFO.json`记录标签/构建号、源码提交、引擎、项目内版本及测试构建性质；`MANIFEST.json`记录包内文件SHA-256。标签不改写项目内版本，两者分别显示，避免旧版本字符串被当成构建来源。

## GitHub 配置与检查

固定Godot4.6.3 Mono与.NET8，解析安装目录中真正的Console EXE并验证版本，先编译C#再验证；安装的导出模板复制到既有发布门使用的隔离APPDATA。验证包括两轮18套、权限/边界/UI、四关矩阵、工具、Windows导出和启动。性能按D-028暂缓，HUMAN与实际FPS不作自动构建通过结论。

默认`GITHUB_TOKEN`足够，不需要把个人token写进仓库。验证任务只有contents:read；只有推送版本标签且验证成功的发布任务具有contents:write。仓库需允许Actions及所引用的固定SHA action；组织策略禁止写权限时，发布会失败，需管理员调整仓库策略。源码提交不会包含gitignore中的本机凭据、构建和验证日志，云端重新生成这些产物。

触发规则依据[GitHub官方文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)；发布使用[工作流中的GitHub CLI](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-github-cli)。
