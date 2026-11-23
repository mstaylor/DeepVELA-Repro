# Plan for Recreating Fig. 4 with Tokens on TACC Vista

## Goal

Recreate the MLPerf 3D U-Net controlled study of Fig. 4 on TACC Vista and report agent tokens per session in place of, or beside, agent calls. The study crosses the seven reference conditions C0 to C6 with the three workflows (Prompt-Only, Skill-guided, Builder + Reproduce) and three trials, which gives 63 sessions. Every session is then repeated with the first round's outputs in the workspace, which gives the "Prior artifacts" bars of Fig. 4 and the before and after split of the token composition table. Both rounds together are 126 agent sessions.

Only 3D U-Net is in scope. The benchmark itself already runs on Vista (`docs/vista-3d-unet-kits19-reproduction.md`), and its data and model are cached on Vista scratch.

## What the figure needs from each session

| Quantity | Source |
|---|---|
| Uncached input, cache write, cache read and output tokens | the agent session transcript, summed over the main session and its subagents |
| Agent calls and failed calls | the same transcript |
| Wall time and outcome | the Slurm job record and the workspace `report.json` |
| Mean, kidney and tumor DICE | the workspace `report.json` |
| GPU power and peak memory (optional) | `nvidia-smi` sampled by the session job |

The bottom panel of Fig. 4 (implementation contract errors) needs each session labeled by hand under the paper's rules in Appendix XII. That labeling is not part of this plan unless you ask for it. The transcripts it needs are kept either way.

## Decisions needed before any session runs

1. **Agent harness and model.** One agent model and one harness revision are used for every session, as the protocol requires for comparable workflows. The paper lists Codex as the harness for every MLPerf row. The only identified pairing in the paper is GPT-5.6 Sol (`gpt-5.6-sol`) with Codex v0.151.0-alpha.7.2, from the Llama-3.1-8B (edge) logs, and the paper states that the mapping for the remaining sessions, including the 3D U-Net study, has not been verified. That pairing is the recommended default unless the lead author confirms another one. Table XVIII reports a cache write column and sums over subagents, which Codex transcripts do not provide, so the token columns we can report depend on this choice. Comparing several agent models is not part of this plan, because the paper does not study it and states that its comparisons cannot isolate agent model effects.
2. **The C1 to C6 masked sources.** The repository ships only the C0 record. The paper describes what each condition removes (appendix table of reference masks) but the masked archives are not in the repository. The best option is to obtain the original six bundles from the authors. Recreating them from the descriptions is possible but would make the conditions our own and not the paper's.
3. **Help level.** Autonomous (`--autonomy`) is recommended so that all 126 sessions run as batch jobs without anyone answering.
4. **Both rounds or round one only.** The token version of Fig. 4 needs both rounds. Round one alone gives the "Fresh workspace" bars only.

## Constraints that shape the design

1. TACC requires every AI assisted workload to run on compute nodes. The agent itself therefore runs inside a Slurm job on a `gh` node, and the login node is used only for staging, `sbatch` and status checks.
2. Each session gets one whole GH200 node, so its GPU work runs on that node directly. This is the repository's `local` compute mode, and the prompt tells the agent not to submit Slurm jobs.
3. The task record names an A100 80GB GPU. The platform is a task fact, so a Vista copy of the record is needed with the GH200 platform, and its prompts and bundles are rendered and sealed again. Condition C2 masks exactly this hardware requirement, so its Vista version masks the GH200 line instead.
4. The `gh` partition allows 20 running and 40 queued jobs per user, with a 48 hour limit. The paper's wall clock cap of one hour per session is kept.
5. The Vista account has no operator configuration (no instructions file, no global skills), which helps isolation. Each session still gets its own agent home directory, as `evaluation.prepare` already does for Codex.

## Phases

### Phase 1. Agent harness on Vista

1. Install the chosen agent CLI as a standalone aarch64 binary under `$WORK`, together with `uv`, in a short CPU job on `gg`. Neither is on Vista today.
2. You log the CLI in once on Vista. Its credentials stay in `$HOME` with user only permissions and every session links to them, as `prepare.py` does for Codex.
3. Fill `docs/local-preferences.md` for Vista. Bundle root and runs root go on `$SCRATCH` outside the repository clone, the study is the three workflows with the chosen model, and the help level is autonomous.
4. Link the cached KiTS19 raw data (without case_00400, as the record says) and the model into the repository's `.cache/3d-unet-kits19/` paths on Vista, so no session downloads them again.

### Phase 2. Task records and bundles

1. Add `dataset/tasks/mlperf-c0-c6/3d-unet-kits19-vista.json`, identical to the C0 record except for the platform line, which names the GH200 node.
2. Author and seal the C0 bundle with `agent-evaluation-profile` author mode. Masking of the reference values follows the existing procedure.
3. Add the six masked bundles C1 to C6, either the authors' originals with only the platform line changed, or our recreation from the paper's descriptions, depending on decision 2. Each is sealed and its `masked.txt` lists exactly what was removed.

### Phase 3. Session runner

1. `hpc/vista/3d-unet-token-study/session.slurm` runs one session on one `gh` node. It takes a run directory that `evaluation.prepare` created, starts the agent in that run's `ws/` with the prompt unchanged under `timeout` at the one hour cap, samples `nvidia-smi` every few seconds if requested, and copies the session transcript into the run directory when the agent exits.
2. `submit_round.sh` prepares and submits the matrix for one round (7 conditions, 3 workflows, 3 trials), keeping at most 20 jobs running, and writes a manifest mapping each job ID to condition, workflow, trial and round.
3. A small extension to `evaluation.prepare` (`--prior-run <run dir>`) builds a round two workspace. It copies the first round's workspace outputs into a fresh run directory but leaves out the first round's transcript and `launch.json`, and keeps the prompt byte identical. The exact rule for which outputs carry over should match the paper's second round and be confirmed with the authors.
4. Before the study, the isolation check from the protocol runs once in a `plain` workspace on a compute node.

### Phase 4. Trace extraction

1. `evaluation/traces.py` reads every transcript and writes one row per session to `sessions.csv` with condition, workflow, trial, round, agent calls, failed calls, uncached input, cache write, cache read, output and total tokens, wall time, outcome and DICE.
2. For Claude Code transcripts, usage is counted once per assistant message ID, because one message can span several transcript lines that repeat the same usage, and subagent transcripts are added in. For Codex transcripts, the final cumulative token count is used, and uncached input is input minus cached input.
3. Unit tests use small transcript fixtures for each harness, including a repeated message ID and a subagent.

### Phase 5. Pilot

1. Round one of C0 only, one trial per workflow (3 sessions), on `gh-dev`.
2. Check that each transcript is complete, that the extractor's totals match the harness's own end of session summary, that the agent stayed inside its workspace and submitted no Slurm job, and that `report.json` holds a DICE value.
3. Compare token magnitudes with the paper's 3D U-Net rows (about 0.63M, 1.02M and 1.20M tokens) as a sanity check only. Different hardware and a different software stack change what the agents must repair, so absolute counts are not expected to match.

### Phase 6. Full study

1. Round one, all 63 sessions on `gh`.
2. Round two, all 63 sessions built from the round one outputs.
3. Fetch every run directory (transcripts, workspaces without large data, Slurm logs, GPU samples) to `~/cylon_experiments/deepvela/vista/3d-unet-token-study/`.

### Phase 7. Figure and tables

1. A two panel figure in the layout of Fig. 4. The top panel shows mean tokens per session for each condition and workflow with "Prior artifacts" and "Fresh workspace" bars and the percent reduction below each pair. The bottom panel shows mean agent calls in the same layout, which reproduces the paper's own top panel. Bars show means only, with no error bars, and the trial spread goes in a table.
2. The before and after token composition table (uncached input, cache read, output) for each workflow, over all seven conditions and three trials.
3. A session inventory table in the form of Table XVIII for the 3D U-Net rows.
4. Charts are saved in the repository under `hpc/vista/3d-unet-token-study/charts/` and the data stays in `~/cylon_experiments/`.

### Phase 8. Report

A report in `docs/` that states the platform, harness, model, what differs from the paper, the full inventory, the figure, and how the relative results (workflow ratios and round two reductions) compare with the paper's.

## Budget

| Item | Estimate |
|---|---|
| Node hours | at most 126 at the one hour cap, plus about 3 for the pilot and setup. The allocation has about 19,800 SU left. |
| Agent tokens | the paper's 3D U-Net sessions used 0.6M to 1.2M tokens each, so about 100M to 150M tokens over both rounds, mostly cache reads. The cost depends on the model and how the account is billed. |
| Elapsed time | with 20 sessions at once, each round takes a few hours of compute once jobs start. Queue wait is the main uncertainty. |

## Risks

1. If the masked bundles or the round two rule differ from the paper's, the comparison with the paper is weaker. Decisions 1 and 2 address this.
2. Agents on aarch64 meet different environment problems (PyTorch wheels, container choice) than on an x86 A100 machine. This affects calls and tokens, so the comparison with the paper should rest on relative effects (workflow ratios, round two reductions), not on absolute counts.
3. Compute nodes must reach the model provider's API. Downloads from compute nodes already work, but the API endpoint is checked in the pilot.
4. Concurrent sessions share the `uv` cache and input caches, which the repository already allows. Each session builds its own environment and outputs.
5. A session that runs into the cap ends incomplete. Its transcript is still kept, and it counts in the inventory as a timeout.

## Order of work

Decisions 1 to 4 first, then phases 1 to 5, a review of the pilot with you, and only then phases 6 to 8.
