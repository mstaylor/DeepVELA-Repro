# Verifying the 3D U-Net Relative Results in the DeepVELA Paper

The question was whether our runs confirm the relative results the paper reports for the MLPerf 3D U-Net benchmark. The three tables in question are the inference quality table, the GPU system profile and the token composition table. Our evidence is the full 3D U-Net KiTS19 accuracy run on TACC Vista, described in `docs/vista-3d-unet-kits19-reproduction.md`.

The short answer is that the quality result is confirmed, the GPU profile is confirmed only in part, and the token results cannot be checked yet because they need agent session traces that we have not collected on Vista.

The tables in the question are numbered X, XII and XIV. In the current CCGrid PDF the quality table is Table XVII and the session token inventory is Table XVIII. The GPU system profile and the before and after token composition table do not appear in the current PDF, which also states that the study measures task quality agreement and not throughput, latency or power. The question appears to refer to an earlier draft, and this answer uses the numbers shown in it.

## 1. Inference quality (confirmed)

| Source | Mean DICE | Kidney | Tumor | Difference from reference |
|---|---|---|---|---|
| Paper reference | 0.862 | | | |
| Paper, Prompt-Only, Skill-guided and Builder + Reproduce | 0.862 each | | | 0.00 |
| MLPerf reference at the pinned commit | 0.86170 | 0.9347 | 0.7887 | |
| Our Vista run, 43 cases | 0.86167 | 0.9347 | 0.7887 | 0.00003 (0.0035% relative) |

Our run reproduces the reference to the precision the paper reports, so the paper's finding that all three workflows match the reference at 0.862 is consistent with an independent run on different hardware. We ran on one NVIDIA GH200 node with an arm64 PyTorch 24.04 container, while the paper used one NVIDIA A100 80GB. No model, preprocessing or evaluation code was changed, and the preprocessed data matched the reference checksums.

We also ran the same job twice on two different nodes and obtained byte-identical per-case scores. The paper notes that its MLPerf cases do not include repeated trials, so this gives some evidence that the 3D U-Net score is repeatable.

Our run confirms the benchmark outcome, not the comparison between workflows. It was a scripted reproduction and was not run through any of the three agent workflows.

## 2. GPU system profile (confirmed in part)

The paper's own figures are internally consistent. With 43 samples, the reported times of 148.7 s, 135.0 s and 145.5 s give 0.29, 0.32 and 0.30 samples per second, which round to the reported 0.3. Dividing energy by time gives 239.4 W, 260.7 W and 255.0 W, which match the power column.

| Measure | Paper (A100 80GB) | Our run (GH200) |
|---|---|---|
| Samples | 43 | 43 |
| Model run time | 135.0 to 148.7 s across the three workflows | 75.3 s and 76.3 s across two runs |
| Throughput | 0.3 samples per second | 0.57 samples per second |
| Spread between runs | about 10% | 1.3% |
| Energy, power and peak memory | 35.2 to 37.1 kJ, 239 to 261 W, 7,660 MiB | not measured |

The absolute times are not comparable because the GPUs differ. The relative point does carry over. All three workflows execute the same benchmark code, so their GPU profiles should agree up to run to run variation. Our two identical runs differ by 1.3%, which suggests that most of the roughly 10% spread in the paper comes from run to run variation and not from the workflow.

We did not sample energy, power or peak GPU memory, so those columns cannot be checked. The paper also does not state whether its time includes the 36 s evaluation step, which our run timed separately.

## 3. Token composition (cannot be checked yet)

The token tables come from the agent session transcripts, which record tool calls, uncached input, cache writes, cache reads and output tokens. Our Vista runs were not agent sessions, so we have no transcripts to compare.

Two checks are possible from the paper alone.

1. The before and after reductions in the token composition table agree with their own columns. For example, uncached input for Prompt-Only falls from 91.4K to 60.0K, which is 34%, and output falls from 21.7K to 12.6K, which is 42%. These values were read from the screenshot.
2. The text states that total tokens increase by 14.6% with Skill-guided and 31.2% with Builder + Reproduce relative to Prompt-Only. Summing Table XVIII over all eleven model rows gives exactly these values. For 3D U-Net alone the increases are larger, 62% and 91% (629.1K, 1.02M and 1.20M tokens). Because the sentence sits beside the 3D U-Net discussion, a reader could take the overall figures as 3D U-Net figures, and the text could say that they are totals over all models.

## What is needed to check the rest

Confirming the token results and Fig. 4 requires running the three workflows on Vista and keeping the traces from each session.

1. The agent session transcript for each session, which gives tool calls, failed calls and tokens by type.
2. The first round artifacts and the second pass that follows them, for the before and after token split.
3. The implementation contract error records counted in the lower panel of Fig. 4.
4. GPU power and memory sampled during the model run, if the system profile table is kept.

TACC requires AI assisted workloads to run on compute nodes, so the agent sessions themselves would run inside Slurm jobs and their traces would be copied back with the run outputs. A plan for this, limited to 3D U-Net with three workflows, conditions C0 to C6 and three trials (63 sessions), will follow separately.
