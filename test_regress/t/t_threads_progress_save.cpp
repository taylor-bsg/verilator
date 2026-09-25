// DESCRIPTION: Verilator: Progress counters across fresh and in-place restore
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

#include "verilated.h"
#include "verilated_save.h"

#include "TestCheck.h"

#include <array>
#include VM_PREFIX_INCLUDE

int errors = 0;

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

    std::array<uint32_t, 8> reference() const { return m_reference; }

    void save(const char* filenamep) {
        VerilatedSave os;
        os.open(filenamep);
        os << m_top;
        os.close();
    }

    void restore(const char* filenamep, const std::array<uint32_t, 8>& reference) {
        VerilatedRestore os;
        os.open(filenamep);
        os >> m_top;
        os.close();
        m_reference = reference;
    }

    void evaluateWithoutClock(uint32_t seed) {
        m_top.seed = seed;
        m_top.eval();
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

int main(int argc, char** argv) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    context.threads(2);
    Instance live{&context, "live", 123};
    const char* const filenamep = VL_STRINGIFY(TEST_OBJ_DIR) "/progress.vltsv";
    uint32_t seed = 123;
    for (uint32_t round = 0; round < 16; ++round) {
        for (uint32_t cycle = 0; cycle < 17; ++cycle) {
            seed = seed * 1664525U + 1013904223U;
            TEST_CHECK_EQ(live.step(seed), true);
        }
        const std::array<uint32_t, 8> saved = live.reference();
        live.save(filenamep);
        // Advance the live model and vary its schedule epoch before restoring.
        for (uint32_t cycle = 0; cycle <= round % 4; ++cycle) {
            seed = seed * 1664525U + 1013904223U;
            live.evaluateWithoutClock(seed);
            TEST_CHECK_EQ(live.step(seed), true);
        }
        live.restore(filenamep, saved);
        Instance fresh{&context, "fresh", 987};
        fresh.restore(filenamep, saved);
        for (uint32_t cycle = 0; cycle < 31; ++cycle) {
            seed = seed * 1664525U + 1013904223U;
            TEST_CHECK_EQ(live.step(seed), true);
            TEST_CHECK_EQ(fresh.step(seed), true);
        }
    }
    if (errors) return 1;
    VL_PRINTF("*-* All Finished *-*\n");
    return 0;
}
