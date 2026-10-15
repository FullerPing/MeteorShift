// node tools/store-art/build.cjs <t1|t2|t3|t4|t5|icon|loading|all>
const path = require('node:path');
const pieces = ['t3', 't2', 'icon', 't1', 't5', 't4', 'loading'];
(async () => {
  const want = process.argv[2] || 'all';
  for (const name of want === 'all' ? pieces : [want]) {
    console.log('==', name);
    await require(path.join(__dirname, 'pieces', name + '.cjs'))();
  }
})().catch(e => { console.error(e); process.exit(1); });
