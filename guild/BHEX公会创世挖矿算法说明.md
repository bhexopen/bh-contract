BHEX公会创世挖矿算法说明
======================

BHEX公会创世挖矿算法是一个公平、透明、可靠的随机数中奖算法。此算法通过对所有用户及算力数据、上一出块信息等进行块 Hash 计算，并将计算结果通过与总算力进行模运算取得中奖号码。算法简单且易于理解，计算结果无法篡改且可重复验证。

出块方法
---------

### 块结构

针对每个用户生成一个块，块的内容由 **144 Bytes** 组成，内容如下：

* 前一个块的 Hash（32 Bytes）
* 用户的 Hash （32 Bytes）
* 所有用户及算力组成的 Merkle Tree 的 Root Hash （32 Bytes）
* 所有奖励内容组成的 Merkle Tree 的 Root Hash （32 Bytes）
* 块高度 （4 Bytes）
* 块时间（4 Bytes）
* 总算力（8 Bytes）

### 块 Hash 生成方式

##### 用户 Hash 生成方式

```python
sha256('用户ID').hexdigest()
```

##### 用户及算力的 Hash 生成方式

1. 对每个用户的ID和算力值进行 Sha256 运算
```python
sha256('用户ID' + '算力值').hexdigest()
```

2. 将上述结果排序，并进行两次 Sha256 运算，构建 Merkle Tree，取 Merkle Tree 根节点作为结果。
```python
get_merkle_root('用户排序列表')
```

##### 奖励内容的 Hash 生成方式

1. 对奖励的币种及数量进行 Sha256 运算
```python
sha256('奖励币种' + '奖励数量').hexdigest()
```
2. 将上述结果排序，并进行两次 Sha256 运算，构建 Merkle Tree，取 Merkle Tree 根节点作为结果。
```python
get_merkle_root('奖励内容排序列表')
```

##### 其他 （块高度、块时间、总算力）

取其内容的字节序列，小端模式。

##### 组合计算

将上述所生成全部内容组合成长度 144 的字节序列，对该字节序列进行两次 Sha256 计算，生产内容即为块 Hash。

### 出块

1. 对上述部分所生成的所有用户块Hash列表排序，并进行 Sha256 运算
```python
hash256(sorted('所有用户Hash')).hexdigest()
```
2. 通过上一步的结果转为十进制大整数，与总算力进行模运算，结果即位中奖用户列表索引
```python
int('hash', 16) % int('总算力值')
```

验证程序
---------
```python
import datetime
import struct
import hashlib
import binascii
import time
from bisect import bisect_right
 
 
def sha256(data):
    """
    Calculates the SHA-256 hash of given bytes.
    :param data: the bytes to hash
    :return: hash value
    """
    return hashlib.sha256(data).digest()
 
 
def sha256d(data):
    """
    Calculates the hash of hash of given bytes.
    """
    return sha256(sha256(data))
 
 
def get_merkle_root(str_list):
    """
    Get hash of the merkle tree root from list.
    :param str_list: str list
    :return: merkle root
    """
    branches = [sha256(item) for item in str_list]
    branches.sort()
    while len(branches) > 1:
        if (len(branches) % 2) == 1:
            branches.append(branches[-1])
 
        branches = [sha256d(a + b) for (a, b) in zip(branches[0::2], branches[1::2])]
 
    return branches[0]
 
 
def init_block(guild_gtp_list, 
               prev_hash, 
               guilds_merkle_hash, 
               bonus_merkle_hash, 
               height, 
               time):
    """
    Build the block and headers with 144 bytes structs.
 
    struct format: '<32s32s32s32sIIq' means:
          < - little-endian
        32s - char[32] for hash of the previous block hash.
        32s - char[32] for hash of the guild name.
        32s - char[32] for hash of the merkle tree root of all guilds.
        32s - char[32] for hash of the merkle tree root of all bonus.
          I - unsigned int[4] for the block height
          I - unsigned int[4] for the block born time.
          q - long long[8] for the gtp quantity of the guild.
    """
    for guild in guild_gtp_list:
        header = struct.pack('<32s32s32s32sIIq',
                             binascii.unhexlify(prev_hash),
                             sha256(guild.get('name')),
                             guilds_merkle_hash,
                             bonus_merkle_hash,
                             height,
                             time,
                             long(guild.get('gtp')))
        guild['header'] = binascii.hexlify(sha256d(header))
 
    return sorted(guild_gtp_list, key=lambda k: k.get('header'))
 
 
def get_lucky_block_index(block_list):
    """
    Generate the lucky number and return the block index which were selected.
    :param block_list: block list with hash headers
    :return: lucky block index
    """
    all_headers = ''
    total_gtp = 0
    number_list = []
    for item in block_list:
        all_headers += item.get('header')
        number_list.append(total_gtp)
        total_gtp += int(item.get('gtp'))
 
    lucky_num = int(binascii.hexlify(sha256(all_headers)), 16) % total_gtp
    lucky_block_index = bisect_right(number_list, lucky_num)
    return lucky_block_index - 1 if lucky_block_index else -1
 
 
def verify(guild_gtp_list, 
           guild_bonus_list, 
           prev_block_hash, 
           block_height, 
           born_time):
 
    guilds_merkle_root_hash = get_merkle_root(
        [(item.get('name')) for item in guild_gtp_list]
    )
    
    bonus_merkle_root_hash = get_merkle_root(
        [(item.get('name') + item.get('amount')) for item in guild_bonus_list]
    )
    
    block_list = init_block(guild_gtp_list,
                            prev_block_hash,
                            guilds_merkle_root_hash,
                            bonus_merkle_root_hash,
                            block_height,
                            born_time)
 
    return block_list[get_lucky_block_index(block_list)]
 
 
if __name__ == '__main__':
 
    # Verify sample
 
    # 1. All guild with gtp of the round to be verified.
    guild_gtp_list = [
        {'id': 1, 'name': 'test1', 'gtp': '100'},
        {'id': 2, 'name': 'test2', 'gtp': '50'},
        {'id': 3, 'name': 'test3', 'gtp': '80'},
    ]
 
    # 2. All bonus of the block.
    guild_bonus_list = [
        {'name': 'bht', 'amount': '100'}
    ]
 
    # 3. The previous block hash
    prev_block_hash = 'b1adf1650bda7e7cee8fdbeb9fbc8cfce71d7bc3d772cd56c06b61fc9d251456'
 
    # 4. Current block height
    height = 10
 
    # 5. Block born timestamp(seconds)
    time = int(
        time.mktime(datetime.datetime.strptime('2018-10-25 10:00:00', 
                                               "%Y-%m-%d %H:%M:%S").timetuple())
    )
 
    # 6. Verify (print the lucky block)
    print 'The lucky block: %s' % verify(guild_gtp_list, 
                                         guild_bonus_list, 
                                         prev_block_hash, 
                                         height, 
                                         time)
```