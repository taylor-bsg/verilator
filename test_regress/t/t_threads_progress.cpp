// DESCRIPTION: Verilator: Independent model progress test
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

#include "verilated.h"
#include "verilated_threads.h"

#include "TestCheck.h"

#include <array>
#include <atomic>
#include <memory>
#include <mutex>
#include <thread>
#include VM_PREFIX_INCLUDE

int errors = 0;

bool checkProgress() {
    const std::array<uint32_t, 8> ordinals{{1, 63, 64, 65, 127, 128, 65536, 0xffffffffU}};
    VlMTaskProgress producer;
    VlMTaskProgress acknowledgment;
    std::array<uint64_t, 8> values{};
    bool passed = true;
    std::thread writer{[&]() {
        for (uint32_t epoch = 1; epoch <= 5000; ++epoch) {
            const bool even = epoch & 1;
            for (uint32_t i = 0; i < ordinals.size(); ++i) {
                values[i] = uint64_t{epoch} * 100 + i;
                producer.publish(even, ordinals[i]);
                if (!((epoch + i) % 17)) std::this_thread::yield();
            }
            acknowledgment.wait(even, 1);
        }
    }};
    for (uint32_t epoch = 1; epoch <= 5000; ++epoch) {
        const bool even = epoch & 1;
        for (uint32_t i = 0; i < ordinals.size(); ++i) {
            producer.wait(even, ordinals[i]);
            if (values[i] != uint64_t{epoch} * 100 + i) passed = false;
            if (!((epoch + i) % 13)) std::this_thread::yield();
        }
        acknowledgment.publish(even, 1);
    }
    writer.join();
    return passed;
}

uint32_t mix(uint32_t a, uint32_t b) {
    uint32_t x = a ^ b;
    for (uint32_t j = 0; j < 24; ++j) { x = ((x << 5) | (x >> 27)) * 0x9e3779b9U + b + j; }
    return x;
}

class Instance final {
    std::array<uint32_t, 8> m_reference{};
    VM_PREFIX m_top;

public:
    Instance(VerilatedContext* contextp, const char* namep, uint32_t seed)
        : m_top{contextp, namep} {
        m_top.clk = 0;
        m_top.rst = 1;
        m_top.seed = seed;
        m_top.eval();
        m_top.clk = 1;
        m_top.eval();
        for (uint32_t i = 0; i < 8; ++i) m_reference[i] = seed ^ (0x1234567U * (i + 1));
        m_top.rst = 0;
    }

    bool step(uint32_t seed) {
        m_top.clk = 0;
        m_top.seed = seed;
        m_top.eval();
        std::array<uint32_t, 8> next;
        for (uint32_t i = 0; i < 8; ++i) {
            next[i] = mix(m_reference[i], m_reference[(i + 1) % 8] ^ seed);
        }
        m_top.clk = 1;
        m_top.eval();
        m_reference = next;
        for (uint32_t i = 0; i < 8; ++i) {
            if (m_top.result[i] != m_reference[i]) return false;
        }
        return true;
    }
};

bool runContext(uint32_t seed, std::mutex& lifecycleMutex) {
    // Destruction/recreation and unequal evaluation counts exercise independent epochs.
    for (uint32_t generation = 0; generation < 3; ++generation) {
        std::unique_ptr<VerilatedContext> contextp;
        std::unique_ptr<Instance> ap;
        std::unique_ptr<Instance> bp;
        {
            // Legacy s_lastContextp is shared by context setup and destruction.
            // Serialize lifecycle operations, including worker startup, not evaluation.
            const std::lock_guard<std::mutex> lock{lifecycleMutex};
            contextp.reset(new VerilatedContext);
            contextp->threads(2);
            static_cast<VlThreadPool*>(contextp->threadPoolp())->workerp(0)->wait();
            ap.reset(new Instance{contextp.get(), "a", seed});
            bp.reset(new Instance{contextp.get(), "b", seed + 1});
        }
        bool passed = true;
        for (uint32_t cycle = 0; cycle < 1001; ++cycle) {
            seed = seed * 1664525U + 1013904223U;
            if (!ap->step(seed) || ((cycle % 3) && !bp->step(seed ^ 0xabcdefU))) {
                passed = false;
                break;
            }
            if (!(cycle % 71)) std::this_thread::yield();
            contextp->timeInc(1);
        }
        {
            const std::lock_guard<std::mutex> lock{lifecycleMutex};
            bp.reset();
            ap.reset();
            contextp.reset();
        }
        if (!passed) return false;
    }
    return true;
}

int main(int argc, char** argv) {
    TEST_CHECK_EQ(checkProgress(), true);
    std::array<bool, 2> passed{{false, false}};
    std::mutex lifecycleMutex;
    std::thread a{[&]() { passed[0] = runContext(123, lifecycleMutex); }};
    std::thread b{[&]() { passed[1] = runContext(987, lifecycleMutex); }};
    a.join();
    b.join();
    TEST_CHECK_EQ(passed[0], true);
    TEST_CHECK_EQ(passed[1], true);
    if (errors) return 1;
    VL_PRINTF("*-* All Finished *-*\n");
    return 0;
}
