## SpecStory

## Debugging Insights for PrevRun Module (3/8/2025, 11:24:15 PM)

_**User**_

I see bad behavior when I apply use this project to debug a complex situation in another project. We need an insight why there's a failure to align when there are large gaps in current run vs. previous run, even though I configured the exploration band max_distance_factor very large. We could be outputting a meta-debug-log to get that information. Let's restrict the meta-debugging to the PrevRun module. We need to see what the optimal edits are at various points, without too much redundant information.

---

_**Assistant**_

I'll help you add meta-debugging to the `PrevRun` module to understand the alignment issues. We'll want to see:

1. The exploration band boundaries being used
2. The optimal edit sequences being computed
3. The costs at key points in the dynamic programming table

Let me add this meta-debugging capability:

---

_****_



---

_****_



---



---

