import math
import random

def ext_euclid(a, b):
    old_s, s = 1, 0
    old_t, t = 0, 1
    old_r, r = a, b
    if b == 0:
        return 1, 0, a
    else:
        while(r!=0):
            q = old_r // r
            old_r, r = r, old_r-q*r
            old_s, s = s, old_s-q*s
            old_t, t = t, old_t-q*t
    return old_s, old_t, old_r

def is_prime(num):
    if (num>1):
        for i in range(2, num):
            if (num % i) == 0:
                return False
        return True
    return False

def generate_key(p, q, e):
    etf = (p-1) * (q-1)
    assert math.gcd(e,etf) == 1
    old_t, t = 0, 1
    old_r, r = etf, e
    if e == 0:
        return 1
    else:
        while(r!=0):
            # print(old_t)
            q = old_r // r
            old_r, r = r, old_r-q*r
            old_t, t = t, old_t-q*t
    # print(old_t)
    if (old_t < 0):
        old_t = old_t + etf
        # print(old_t)
    assert old_t > 0
    assert (e * old_t) % etf == 1
    return old_t

def encrypt(m,e,N):
    c = 1
    for i in range(e):
        c = (c * m) % N
    return c

def decrypt(c,d,N):
    m = 1
    for i in range(d):
        m = (m * c) % N
    return m

# Soft ip pattern
with open('input_ip.txt','w') as f:
    prime_list = [i for i in range(2**3) if is_prime(i)]
    p_list = prime_list
    q_list = prime_list
    input_list = [(p,q,i) for p in p_list for q in q_list for i in range(2,(p-1)*(q-1)) if ((p!=q) and math.gcd(i,(p-1)*(q-1))==1)]
    
    pat = len(input_list)
    f.write(str(pat)+'\n')
    f.write('\n')
    for tup in input_list:
        f.write(' '.join([str(i) for i in tup])+'\n')

# Top pattern
with open('input.txt','w') as f:
    random.seed(0)

    prime_list = [i for i in range(2**4) if is_prime(i)]
    p_list = prime_list
    q_list = prime_list
    input_list = [(p,q,i) for p in p_list for q in q_list for i in range(2,(p-1)*(q-1)) if ((p!=q) and math.gcd(i,(p-1)*(q-1))==1)]
    
    pat = len(input_list)
    f.write(str(pat)+'\n')

    for p,q,e in input_list:
        # etf = (p-1) * (q-1)
        # assert math.gcd(e,etf) == 1
        # d = generate_key(e,etf)
        # assert d > 0
        # assert (e * d) % etf == 1
        d = generate_key(p,q,e)
        N = p * q
        m_list = [random.randint(0,N-1) for i in range(8)]
        for m in m_list:
            assert m == decrypt(encrypt(m,e,N),d,N)
        
        f.write(' '.join([str(i) for i in (p,q,e)])+'\n')
        f.write(' '.join([str(encrypt(m,e,N)) for m in m_list])+'\n')
        f.write(' '.join([str(m) for m in m_list])+'\n')