#!/usr/bin/env python3
"""
CPU性能测试程序
测试CPU的计算能力、多进程性能、多线程I/O性能和内存访问速度
修复了多线程CPU密集型任务的性能问题
"""

import time
import threading
import multiprocessing
import math
import random
from functools import reduce

def worker(iterations):
    """多进程工作函数 - 必须在模块级别定义"""
    pi = 0
    for i in range(iterations):
        pi += (-1) ** i / (2 * i + 1)
    return pi * 4

class CPUTest:
    def __init__(self):
        self.results = {}

    def test_single_thread_performance(self, duration=5):
        """测试单线程计算性能"""
        print("测试单线程计算性能...")

        def compute_pi(iterations):
            pi = 0
            for i in range(iterations):
                pi += (-1) ** i / (2 * i + 1)
            return pi * 4

        iterations = 1000000
        start_time = time.time()
        count = 0

        while time.time() - start_time < duration:
            compute_pi(iterations)
            count += 1

        elapsed = time.time() - start_time
        operations_per_second = (count * iterations) / elapsed

        self.results['single_thread_ops_per_sec'] = operations_per_second
        print(f"单线程计算性能: {operations_per_second:,.2f} ops/sec")
        return operations_per_second

    def test_multi_process_performance(self, duration=5):
        """测试多进程计算性能"""
        print(f"测试多进程计算性能 (进程数: {multiprocessing.cpu_count()})...")

        iterations = 1000000
        num_processes = min(multiprocessing.cpu_count(), 16)  # 限制进程数避免过多开销
        pool = multiprocessing.Pool(processes=num_processes)

        start_time = time.time()
        count = 0

        try:
            while time.time() - start_time < duration:
                results = pool.map(worker, [iterations] * num_processes)
                count += 1
        finally:
            pool.close()
            pool.join()

        elapsed = time.time() - start_time
        operations_per_second = (count * iterations * num_processes) / elapsed

        self.results['multi_process_ops_per_sec'] = operations_per_second
        print(f"多进程计算性能: {operations_per_second:,.2f} ops/sec")
        return operations_per_second

    def test_multi_thread_performance(self, duration=5):
        """测试多线程计算性能 (I/O型任务)"""
        print(f"测试多线程计算性能 (线程数: {multiprocessing.cpu_count()})...")

        def worker(iterations, result_list, index):
            # 模拟I/O操作的时候多线程才有优势
            pi = 0
            for i in range(iterations):
                pi += (-1) ** i / (2 * i + 1)
                # 添加短暂延迟模拟I/O操作
                if i % 1000 == 0:
                    time.sleep(0.001)
            result_list[index] = pi * 4

        iterations = 100000
        num_threads = multiprocessing.cpu_count()
        threads = []
        results = [0] * num_threads

        start_time = time.time()
        count = 0

        while time.time() - start_time < duration:
            results = [0] * num_threads
            threads = []

            for i in range(num_threads):
                thread = threading.Thread(target=worker, args=(iterations, results, i))
                threads.append(thread)
                thread.start()

            for thread in threads:
                thread.join()

            count += 1

        elapsed = time.time() - start_time
        operations_per_second = (count * iterations * num_threads) / elapsed

        self.results['multi_thread_ops_per_sec'] = operations_per_second
        print(f"多线程计算性能 (I/O型): {operations_per_second:,.2f} ops/sec")
        return operations_per_second

    def test_math_operations(self, duration=5):
        """测试数学运算性能"""
        print("测试数学运算性能...")

        operations = 0
        start_time = time.time()

        while time.time() - start_time < duration:
            for i in range(10000):
                x = math.sin(i) + math.cos(i) + math.log(i + 1) + math.sqrt(i + 1)
                operations += 4

        elapsed = time.time() - start_time
        operations_per_second = operations / elapsed

        self.results['math_ops_per_sec'] = operations_per_second
        print(f"数学运算性能: {operations_per_second:,.2f} ops/sec")
        return operations_per_second

    def test_memory_access(self, duration=5):
        """测试内存访问速度"""
        print("测试内存访问速度...")

        size = 1000000
        arr = [random.random() for _ in range(size)]

        start_time = time.time()
        accesses = 0

        while time.time() - start_time < duration:
            for i in range(size):
                arr[i] = math.sin(arr[i]) * math.cos(arr[i])
                accesses += 1

        elapsed = time.time() - start_time
        accesses_per_second = accesses / elapsed

        self.results['memory_accesses_per_sec'] = accesses_per_second
        print(f"内存访问速度: {accesses_per_second:,.2f} accesses/sec")
        return accesses_per_second

    def test_prime_generation(self, duration=5):
        """测试质数生成性能"""
        print("测试质数生成性能...")

        def is_prime(n):
            if n < 2:
                return False
            for i in range(2, int(math.sqrt(n)) + 1):
                if n % i == 0:
                    return False
            return True

        start_time = time.time()
        primes_found = 0
        current_num = 2

        while time.time() - start_time < duration:
            if is_prime(current_num):
                primes_found += 1
            current_num += 1

        elapsed = time.time() - start_time
        primes_per_second = primes_found / elapsed

        self.results['primes_per_sec'] = primes_per_second
        print(f"质数生成速度: {primes_per_second:,.2f} primes/sec")
        return primes_per_second

    def test_sorting_performance(self, duration=5):
        """测试排序性能"""
        print("测试排序性能...")

        start_time = time.time()
        sorts_performed = 0

        while time.time() - start_time < duration:
            # 生成随机数组
            arr = [random.random() for _ in range(10000)]
            # 排序
            arr.sort()
            sorts_performed += 1

        elapsed = time.time() - start_time
        sorts_per_second = sorts_performed / elapsed

        self.results['sorts_per_sec'] = sorts_per_second
        print(f"排序速度: {sorts_per_second:,.2f} sorts/sec")
        return sorts_per_second

    def run_all_tests(self):
        """运行所有测试"""
        print("=" * 50)
        print("CPU性能测试开始")
        print("=" * 50)

        # 获取CPU信息
        print(f"CPU核心数: {multiprocessing.cpu_count()}")
        print(f"测试时长: 每项测试5秒")
        print()

        # 运行测试
        self.test_single_thread_performance()
        self.test_multi_process_performance()
        self.test_multi_thread_performance()
        self.test_math_operations()
        self.test_memory_access()
        self.test_prime_generation()
        self.test_sorting_performance()

        print()
        print("=" * 50)
        print("测试结果汇总:")
        print("=" * 50)

        for test_name, result in self.results.items():
            formatted_name = test_name.replace('_', ' ').title()
            print(f"{formatted_name}: {result:,.2f}")

        # 计算综合得分
        avg_score = sum(self.results.values()) / len(self.results)
        print(f"\n综合性能得分: {avg_score:,.2f}")

        return self.results

def main():
    """主函数"""
    try:
        cpu_test = CPUTest()
        results = cpu_test.run_all_tests()

        print("\n测试完成！")

    except KeyboardInterrupt:
        print("\n测试被用户中断")
    except Exception as e:
        print(f"测试过程中发生错误: {e}")

if __name__ == "__main__":
    main()