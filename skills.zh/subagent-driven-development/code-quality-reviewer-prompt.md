# 代码质量审查者子代理提示模板

派发代码质量审查子代理时使用此模板。

**目的：** 验证实现是否构建得当（整洁、经过测试、可维护）

**仅在规范符合性审查通过后派发。**

```
任务工具（superpowers:code-reviewer）：
  使用 requesting-code-review/code-reviewer.md 中的模板

  WHAT_WAS_IMPLEMENTED: [来自实现者汇报]
  PLAN_OR_REQUIREMENTS: 来自 [plan-file] 的任务 N
  BASE_SHA: [任务开始前的提交]
  HEAD_SHA: [当前提交]
  DESCRIPTION: [任务摘要]
```

**除标准代码质量关注点外，审查者还应检查：**
- 每个文件是否只有一个清晰职责，并且接口明确？
- 各个单元是否拆分得足够清楚，便于理解和独立测试？
- 实现是否遵循了计划中的文件结构？
- 这次实现是否创建了已经很大的新文件，或显著增大了现有文件？（不要针对原本就很大的文件报问题，只关注这次改动新增的部分。）

**代码审查者返回：** 优点、问题（Critical/Important/Minor）、评估结论
