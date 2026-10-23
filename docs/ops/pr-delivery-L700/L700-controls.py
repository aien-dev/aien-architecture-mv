import pathlib, subprocess, os, tempfile, json
h=pathlib.Path.home(); w=h/'workspace/hermes-desk/architecture-planner-L700'; out=h/'handoffs/L700-parent-replay'
base='1a3594340c70969c245554b07062efd8ead8a026'
assert subprocess.check_output(['git','-C',str(w),'rev-parse','HEAD'],text=True).strip()=='89a870f612976bcaf358ff3f7414313d879544df'
binary=h/'workspace/pipeline/target-sc/release/aien-test'
def plan(name,*extra,cwd=w):
 r=subprocess.run([str(binary),'plan','--base',base,'--repo','github.com/aien-dev/aien-architecture',*extra],cwd=cwd,text=True,capture_output=True,timeout=120)
 (out/(name+'.log')).write_text(r.stdout+r.stderr);return r
# Mapping correction cannot self-authorize a changed pipeline.
r=plan('default-operator-hold')
assert r.returncode!=0 and 'BLOCKED_OPERATOR PIPELINE_CONFIG_CHANGED' in r.stdout
# The planner reads committed Git objects, not dirty working files. The first
# uncommitted-deletion control was invalid and is preserved separately.
mutant=out/'mutant-worktree'
assert not mutant.exists()
subprocess.run(['git','-C',str(w),'worktree','add','--detach',str(mutant),'HEAD'],check=True)
try:
 subprocess.run(['git','-C',str(mutant),'rm','tests/gates/arch-spark-broker.gate'],check=True)
 subprocess.run(['git','-C',str(mutant),'commit','-m','test: remove broker mapping negative control'],check=True)
 (out/'mutant-head.txt').write_text(subprocess.check_output(['git','-C',str(mutant),'rev-parse','HEAD'],text=True))
 r=plan('committed-missing-gate-mutant','--operator',cwd=mutant)
 assert r.returncode!=0 and 'tools/ops/spark-broker/spark-broker.c' in r.stdout.split('UNMAPPED:',1)[1]
finally:
 subprocess.run(['git','-C',str(w),'worktree','remove',str(mutant)],check=True)
# A failed broker suite cannot emit the gate's successful observation.
with tempfile.TemporaryDirectory(prefix='gate-refusal-',dir=out) as tmp:
 p=pathlib.Path(tmp)/'make';p.write_text('#!/bin/sh\nexit 17\n');p.chmod(0o700)
 env=dict(os.environ,PATH=tmp+':'+os.environ['PATH'])
 r=subprocess.run(['bash',str(w/'tests/gates/run.sh'),'spark-broker'],cwd=w,env=env,text=True,capture_output=True,timeout=30)
 (out/'failed-suite-control.log').write_text(r.stdout+r.stderr+'\nexit='+str(r.returncode)+'\n')
 assert r.returncode==17 and 'AIEN-OBS spark_broker_suite 1' not in r.stdout
assert not subprocess.check_output(['git','-C',str(w),'status','--porcelain'],text=True).strip()
print(json.dumps({'default_operator_hold_preserved':True,'missing_gate_mutant_refused':True,'failed_suite_cannot_emit_success':True,'source_clean':True}))
