# Skillfy

🌍 [English](../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | **中文**

![macOS: 支持](https://img.shields.io/badge/macOS-支持-brightgreen?style=for-the-badge&logo=apple&logoColor=white)
![Linux: 支持](https://img.shields.io/badge/Linux-支持-brightgreen?style=for-the-badge&logo=linux&logoColor=white)
![Windows: 使用WSL](https://img.shields.io/badge/Windows-使用WSL-blue?style=for-the-badge&logo=windows&logoColor=white)

> **Windows用户**：请使用 [WSL (Windows Subsystem for Linux)](https://learn.microsoft.com/zh-cn/windows/wsl/install) 运行Skillfy。

将您的反馈转化为可复用的Claude Code技能(Skill)。

这是一个Claude Code插件，将您的反馈转化为持久学习。

## 核心理念

```
Claude的输出与期望不符时
       ↓
使用/skillfy记录
       ↓
使用/skillfy review升级为技能(Skill)
       ↓
之后Claude自动应用该规则
```

## 安装

首先将插件添加到本地市场，然后安装：
```bash
/plugin marketplace add https://github.com/yhzion/claude-code-skillfy.git
/plugin install skillfy@claude-code-skillfy
```

### 更新

```bash
/plugin marketplace update claude-code-skillfy
```

### 卸载

要完全删除插件，先卸载再从市场中移除：
```bash
/plugin uninstall skillfy@claude-code-skillfy
/plugin marketplace remove claude-code-skillfy
```

## 使用方法

### 初始化

```bash
/skillfy init
```

创建Skillfy数据库和目录结构。

> **注意**：Skillfy安装在Git仓库根目录。如果不是Git仓库，则安装在当前目录。

<details>
<summary>📖 详细说明</summary>

**创建内容：**
- `.claude/skillfy/patterns.db` - SQLite数据库
- `.claude/skills/` - 已升级技能(Skill)的存储目录
- 在`.gitignore`中添加条目（如果是Git项目）

**流程：**

1. **确认：**
   - "初始化Skillfy？" → [是，初始化] [取消]

2. **如果已存在：**
   - "Skillfy已存在" → [保留] [重新初始化（删除数据）]
   - 注：架构升级通过重新初始化处理。没有原地迁移，如需保留数据请先备份。

3. **完成：**
   ```
   Skillfy初始化完成

   - .claude/skillfy/patterns.db 已创建
   - .claude/skills/ 目录已创建
   - .gitignore 已更新（如果是Git项目）

   现在可以使用/skillfy记录不匹配项。
   使用/skillfy review将保存的模式升级为技能。
   ```

</details>

---

### 记录不匹配

```bash
/skillfy
```

当Claude生成的结果与期望不符时记录模式。

<details>
<summary>📖 详细说明</summary>

> **智能建议**：Claude分析当前会话上下文，在每个步骤动态建议相关选项。如果建议不符合需求，可以选择"手动输入"。

**第1步：选择情境**（最多500字符）

Claude分析当前会话并建议相关情境：
```
记录模式不匹配

发生在什么情境下？

1. {基于上下文分析的建议情境}
2. {基于最近错误/修正的另一建议}
3. 手动输入

选择：
```

**第2步：选择期望**（最多1000字符）

Claude根据选择的情境建议期望：
```
您期望什么？

1. {基于情境的建议期望}
2. {另一个相关期望}
3. 手动输入

选择：
```

**第3步：选择指令**（最多2000字符）

Claude建议可执行的指令：
```
Claude应该学习什么规则？（使用祈使句）

1. {建议指令 - 例如："始终包含时间戳字段"}
2. {另一个指令选项}
3. 手动输入

选择：
```

**第4步：选择操作**
```
记录摘要

情境：{情境}
期望：{期望}
指令：{指令}

您想怎么做？

1. 注册为技能 - 立即创建技能文件
2. 保存为备忘 - 存储到数据库以便稍后查看
3. 取消

选择：
```

</details>

---

### 查看并升级为技能

```bash
/skillfy review
```

查看保存的模式并将其升级为技能(Skill)。

<details>
<summary>📖 详细说明</summary>

**第1步：查看已保存的模式**
```
已保存的模式（尚未升级）

[id=12] 创建模型时 → 始终包含时间戳字段 (2024-12-18)
[id=15] 编写API端点时 → 始终包含错误处理 (2024-12-17)

输入要升级的模式id（多选用逗号分隔，取消输入'skip'）：
示例：12 或 12,15
```

**第2步：技能预览**
```
技能预览：{情境}

---
name: {短横线格式的情境}
description: {指令}。在{情境}情境下自动应用。
learned_from: skillfy ({创建日期})
---

## 规则

{指令}

## 适用场景

- {情境}

## 示例

### 正确做法

（在此添加正面示例）

### 错误做法

（在此添加反面示例）

## 学习历史

- 创建时间：{创建日期}
- 来源：通过/skillfy手动记录

---

[保存] [编辑] [跳过]
```

**第3步：结果**
```
✅ 技能已创建

- .claude/skills/{技能名}/SKILL.md

🔄 重启Claude Code以激活此技能。
```

</details>

---

### 查看帮助

```bash
/skillfy help
```

显示可用命令和当前状态。

<details>
<summary>📖 详细说明</summary>

**输出（已初始化时）：**
```
📚 Skillfy帮助

状态：✅ 已初始化 | 模式：{数量} | 技能：{数量} | 待处理：{数量}

命令：
  /skillfy init      初始化Skillfy
  /skillfy           记录期望不匹配
  /skillfy review    将模式升级为技能
  /skillfy reset     删除所有数据
  /skillfy help      显示此帮助

快速开始：
  1. /skillfy init → 2. /skillfy → 3. /skillfy review
```

</details>

---

### 重置数据

```bash
/skillfy reset
```

⚠️ 删除所有模式记录。已创建的技能会保留。

<details>
<summary>📖 详细说明</summary>

**选项：**
- `/skillfy reset` - 仅删除数据库记录（保留技能）
- `/skillfy reset --all` - 删除所有内容包括技能
  > ⚠️ **警告**：此选项会删除整个`.claude/skills/`目录，包括非Skillfy创建的技能。使用前请备份重要技能。

**第1步：当前状态**
```
⚠️ Skillfy重置

数据库文件：
- {DB_PATH}

将删除的数据：
- {数量}个模式

注：已创建的技能（.claude/skills/）将被保留。
```

**第2步：确认**
- "确定要删除所有Skillfy数据吗？"
- [是，重置所有数据] [取消]

**第3步：结果**
```
✅ Skillfy数据已重置

- 模式：全部删除
- 技能：保留（.claude/skills/）

使用/skillfy开始新的记录。
```

</details>

## 示例

学习Skillfy使用方法的两个常见场景。

### 示例1：代码风格偏好

让我们从头到尾看一个真实场景。

#### 😤 问题场景

让Claude创建React组件：

```
> 创建一个Button组件
```

Claude的回复：
```jsx
const Button = ({ label, onClick }) => {
  return <button onClick={onClick}>{label}</button>
}
```

**我想要的是TypeScript接口！** 这种情况反复出现...

---

#### 📝 第1步：记录不匹配

不匹配发生后立即运行`/skillfy`：

```
情境：> 创建React组件时
期望：> props的TypeScript接口
指令：> 始终为组件props定义TypeScript接口

您想怎么做？
> 1. 注册为技能
```

结果：
```
✅ 技能已创建：.claude/skills/creating-react-components/SKILL.md

🔄 重启Claude Code以激活此技能。
```

---

#### ✨ 第2步：结果

**重启Claude Code**后，同样的问题：

```
> 创建一个Button组件
```

现在Claude的回复：
```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
}

const Button = ({ label, onClick }: ButtonProps) => {
  return <button onClick={onClick}>{label}</button>
}
```

🎉 **Claude学会了您的偏好，并自动应用！**

---

### 示例2：工作流行为偏好

学习如何教Claude自动处理还是询问确认。

#### 😤 问题场景

让Claude检查代码质量：

```
> 检查lint和格式
```

Claude发现问题并询问：
```
发现问题：

| 检查     | 状态                           |
|----------|--------------------------------|
| ESLint   | ⚠️ 1个警告                     |
| Prettier | ❌ 2个文件需要格式化           |

要修复这些问题吗？
```

**直接修复就好了！** 不想每次都被问...

---

#### 📝 第1步：记录不匹配

不匹配发生后立即运行`/skillfy`：

```
情境：> 检查lint/格式时
期望：> 不询问直接自动修复，修复后再报告
指令：> 不询问直接修复，修复后报告

您想怎么做？
> 1. 注册为技能
```

结果：
```
✅ 技能已创建：.claude/skills/when-checking-lintformat/SKILL.md

🔄 重启Claude Code以激活此技能。
```

---

#### ✨ 第2步：结果

**重启Claude Code**后，同样的问题：

```
> 检查lint和格式
```

现在Claude的回复：
```
技能指示我不询问直接修复。现在开始修复问题。

✅ 所有问题已修复：

| 检查     | 结果                                           |
|----------|------------------------------------------------|
| Prettier | ✅ 已格式化2个文件（App.vue、HelloWorld.vue）  |
| ESLint   | ✅ 0个错误，0个警告                            |

更改内容：
- src/App.vue — 格式已修复
- src/components/HelloWorld.vue — 格式已修复 + 添加了默认值
```

🎉 **Claude学会了您的工作流偏好，不再询问直接处理！**

---

#### ⚠️ 注意：技能激活

技能不一定总是自动触发。如果Claude没有应用技能：

1. **改进描述** - 使技能的`description`字段更具体
2. **手动调用** - 可以明确调用：
   ```
   > 检查lint和格式。使用技能：when-checking-lintformat
   ```
3. **检查技能加载** - 运行`/skillfy help`验证技能是否被识别

---

## 最佳实践

推荐工作流：

```
1. 像往常一样与Claude协作
       ↓
2. 发现不匹配？立即运行/skillfy
       ↓
3. 要具体："编码时" < "创建React组件时"
       ↓
4. 写清楚指令："始终使用TypeScript接口"
       ↓
5. 重启Claude Code以激活新技能
```

**技巧：**
- 📝 **发生时立即**记录不匹配 - 上下文很重要
- 🎯 情境要**具体** - 模糊的模式没有帮助
- ✍️ 写**祈使句指令** - "始终做X"或"绝不做Y"
- 🚀 创建技能后**重启Claude Code**以加载

## 工作原理

1. **记录**：使用`/skillfy`记录Claude输出与期望不符的情况
2. **保存或升级**：保存为备忘以便稍后查看，或立即创建技能
3. **查看**：使用`/skillfy review`将保存的模式升级为技能
4. **应用**：升级为技能后，Claude在类似情况下自动应用

## 数据存储

| 文件 | 用途 |
|------|------|
| `.claude/skillfy/patterns.db` | SQLite数据库（`patterns`、`schema_version`表） |
| `.claude/skills/*/SKILL.md` | 已升级的技能 |

### 技能命名规则

创建技能时，名称从情境自动生成：

| 规则 | 示例 |
|------|------|
| 转为小写 | "Creating Models" → "creating-models" |
| 空格替换为连字符 | "API endpoint" → "api-endpoint" |
| 删除特殊字符 | "React (TSX)" → "react-tsx" |
| 最多50字符 | 超出时截断 |
| 冲突处理 | 添加后缀：`-1`、`-2`等 |

## 安全注意事项

### 数据隐私

- **patterns.db可能包含敏感数据**：数据库存储您记录的情境和期望。请注意您包含的信息。
- **自动.gitignore**：init命令会自动将`.claude/skillfy/`添加到`.gitignore`以防止意外提交。
- **提交前检查技能文件**：`.claude/skills/`中生成的技能不在gitignore中。提交到版本控制前请检查是否有敏感内容。
- **备份排除**：如果包含敏感信息，考虑从云同步服务中排除`.claude/skillfy/`。

### 文件权限

初始化时会**自动设置**安全权限：

| 路径 | 权限 | 说明 |
|------|------|------|
| `.claude/skillfy/` | `700`（rwx------） | 仅所有者：读、写、执行 |
| `.claude/skills/` | `700`（rwx------） | 仅所有者：读、写、执行 |
| `patterns.db` | `600`（rw-------） | 仅所有者：读、写 |

### 输入验证
- SQL注入通过引号转义防止
- 路径遍历在技能名称生成中被防止

## 故障排除

### 常见问题

**"需要sqlite3但未安装"**
- macOS/Linux：sqlite3通常已预装
- Windows：从 https://sqlite.org/download.html 安装

**技能未被应用**
- 确认技能已正确创建（使用`/skillfy help`检查状态）
- 验证`.claude/skills/`中存在技能文件
- **重启Claude Code**以加载新技能

## 系统要求

- Claude Code
- sqlite3 CLI（macOS/Linux已预装）
- SQLite 3.24.0或更高版本（提升性能和兼容性）
- `realpath`或`python3`（用于review命令的路径解析；通常已预装）

## 许可证

MIT
