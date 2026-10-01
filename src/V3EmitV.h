// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: Emit Verilog code for module tree
//
// Code available from: https://verilator.org
//
//*************************************************************************
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2003-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************

#ifndef VERILATOR_V3EMITV_H_
#define VERILATOR_V3EMITV_H_

#include "config_build.h"
#include "verilatedos.h"

#include <map>

class AstNetlist;
class AstNode;
class AstNodeDType;
class AstSenTree;

//============================================================================

class V3EmitV final {
public:
    class TypeEmitter final {
        // LinkParse's nominal type name to a reference to its original source declaration.
        std::map<std::string, std::string> m_typeNames;

    public:
        explicit TypeEmitter(const AstNetlist* netlistp);
        void verilogForType(AstNodeDType* dtypep, const std::string& name, std::ostream& os) const;
    };

    static void verilogForTree(const AstNode* nodep, std::ostream& os = std::cout);
    static void debugVerilogForTree(const AstNode* nodep, std::ostream& os);
    static std::string debugVerilogForTree(const AstNode* nodep);
    static void emitvFiles();
    static void debugEmitV(const string& filename);
};

#endif  // Guard
