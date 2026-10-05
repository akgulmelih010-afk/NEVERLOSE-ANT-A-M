import re,sys
src=open(sys.argv[1]).read().split('\n')
depth=0; count=0; peak=0
for line in src:
    if line.startswith('do') and line.strip()=='do':
        depth+=1; continue
    if depth>0 and line.strip()=='end' and not line.startswith(' '):
        depth-=1; continue
    if depth==0 and line.startswith('local '):
        m=re.match(r'local function (\w+)',line)
        if m: count+=1; continue
        names=line[6:].split('=')[0]
        count+=len([n for n in names.split(',') if n.strip()])
print(count)
