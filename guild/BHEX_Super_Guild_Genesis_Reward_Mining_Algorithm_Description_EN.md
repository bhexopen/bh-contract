BHEX Super Guild Genesis Reward Algorithm Description

======================


BHEX Super Guild Genesis Reward Algorithm is a fair, transparent and reliable random number election algorithm. The principle of the algorithm is to perform Hash calculation by packing the GTP of every guild member and the information of previous block. The random selection is by sorting the hash value of the calculated result and performing the modulo operation of total mining power. The algorithm is easy understanding, and the result can be verified repeatedly and cannot be manipulate. 


Block Production Method
---------

### Block Structure


Every user will be produced one block, the content of the block consists of **144 Bytes**. The contents are as follows:
*the Hash of previous block (32 Bytes)
*the Hash of the user (32 Bytes)
*the Root Hash of combined Merkle Tree of all users and all GTP (32 Bytes)
*the Root Hash of combined Merkle Tree of all rewards (32 Bytes)
*Block height (32 Bytes)
*Block time (32 Bytes)
*Total GTP (8 Bytes)

### the production method of block hash 
#### the production method of user Hash


```python
sha256(‘user ID’). hexdigest()
```

##### the production method of the hash of user and GTP

Conduct Sha256 algorithm to every user ID and GTP
```python
sha256(' user ID’' + 'GTP').hexdigest()
```
2. Ranking above results, and conduct Sha256 algorithm twice, construct Merkle Tree and pick the root hash of Merkle Tree as result.
```python
get_merkle_root('user ranking list ')
```

##### the production method of the Hash of reward
1. Conduct Sha256 algorithm to reward coin type and number
```python
sha256('reward coin type' + 'reward number').hexdigest()
```
2. Ranking above results, and conduct Sha256 algorithm twice, construct Merkle Tree and pick the root hash of Merkle Tree as result.
```python
get_merkle_root('reward ranking list ')
```

##### others (Block height, Block time, Total GTP) 
 Select the content endianness in little-endian mode. 

##### Combined Calculation

Combine all the contents montioned above to an endianness of 144 bytes and perform two SHA256 calculations, the contents of the result are the hash block. 

### block production
1. Ranking above all produced user block hash, and conduct Sha256 algorithm
```python
hash256(sorted('all user Hash')).hexdigest()
```
2. convert the above result to decimalise integer, conduct modulo algorithm to total GTP. The result is the sort the winning user. 
```python
int('hash', 16) % int('Total GTP ')
```

Verify Algorithm
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