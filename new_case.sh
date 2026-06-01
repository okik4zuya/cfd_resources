#!/bin/bash
# new_case.sh — OpenFOAM case boilerplate generator
# Usage: bash /scripts/new_case.sh <case_path>
# Example: bash /scripts/new_case.sh /workspace/cases/phase0_mesh/rung1_channel

set -e

# ── argument check ──────────────────────────────────────────────────────────
if [ -z "$1" ]; then
    echo "Usage: bash $0 <case_path>"
    echo "Example: bash $0 /workspace/cases/phase0_mesh/rung1_channel"
    exit 1
fi

CASE="$1"

if [ -d "$CASE" ]; then
    echo "Error: '$CASE' already exists. Aborting to avoid overwrite."
    exit 1
fi

# ── directory structure ──────────────────────────────────────────────────────
mkdir -p "$CASE/constant/polyMesh"
mkdir -p "$CASE/system"
mkdir -p "$CASE/0"

# ── constant/polyMesh/blockMeshDict ─────────────────────────────────────────
cat > "$CASE/constant/polyMesh/blockMeshDict" << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "constant/polyMesh";
    object      blockMeshDict;
}

scale 1;

vertices
(
    // TODO: define vertices
    // Format: (x y z)
);

blocks
(
    // TODO: define blocks
    // Format: hex (v0..v7) (Nx Ny Nz) simpleGrading (gx gy gz)
);

edges ( );

boundary
(
    // TODO: define boundary patches
    // Format:
    // patchName { type wall/patch/symmetryPlane/empty; faces ( (v0 v1 v2 v3) ); }
);

mergePatchPairs ( );
EOF

# ── system/controlDict ───────────────────────────────────────────────────────
cat > "$CASE/system/controlDict" << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}

application     icoFoam;       // TODO: change to your solver

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         1;
deltaT          0.001;

writeControl    timeStep;
writeInterval   100;

purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
runTimeModifiable true;
EOF

# ── system/fvSchemes ─────────────────────────────────────────────────────────
cat > "$CASE/system/fvSchemes" << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "system";
    object      fvSchemes;
}

ddtSchemes
{
    default         Euler;
}

gradSchemes
{
    default         Gauss linear;
}

divSchemes
{
    default         none;
    div(phi,U)      Gauss linearUpwind grad(U);
}

laplacianSchemes
{
    default         Gauss linear corrected;
}

interpolationSchemes
{
    default         linear;
}

snGradSchemes
{
    default         corrected;
}
EOF

# ── system/fvSolution ────────────────────────────────────────────────────────
cat > "$CASE/system/fvSolution" << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "system";
    object      fvSolution;
}

solvers
{
    p
    {
        solver          GAMG;
        tolerance       1e-06;
        relTol          0.1;
        smoother        GaussSeidel;
    }

    U
    {
        solver          smoothSolver;
        smoother        GaussSeidel;
        tolerance       1e-05;
        relTol          0.1;
    }
}

SIMPLE
{
    nNonOrthogonalCorrectors 2;
    residualControl
    {
        p               1e-4;
        U               1e-4;
    }
}

PISO
{
    nCorrectors         2;
    nNonOrthogonalCorrectors 1;
}
EOF

# ── 0/U (velocity initial condition placeholder) ─────────────────────────────
cat > "$CASE/0/U" << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       volVectorField;
    location    "0";
    object      U;
}

dimensions      [0 1 -1 0 0 0 0];   // m/s

internalField   uniform (0 0 0);

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform (1 0 0);  // TODO: set inlet velocity (m/s)
    }

    outlet
    {
        type            zeroGradient;
    }

    // TODO: add remaining patches (wall, symmetry, etc.)

    frontAndBack
    {
        type            empty;
    }
}
EOF

# ── 0/p (pressure initial condition placeholder) ─────────────────────────────
cat > "$CASE/0/p" << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       volScalarField;
    location    "0";
    object      p;
}

dimensions      [0 2 -2 0 0 0 0];   // m2/s2 (kinematic pressure)

internalField   uniform 0;

boundaryField
{
    inlet
    {
        type            zeroGradient;
    }

    outlet
    {
        type            fixedValue;
        value           uniform 0;
    }

    // TODO: add remaining patches

    frontAndBack
    {
        type            empty;
    }
}
EOF

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "✓ Case created: $CASE"
echo ""
echo "Structure:"
find "$CASE" | sed 's|[^/]*/|  |g'
echo ""
echo "Next steps:"
echo "  1. Edit constant/polyMesh/blockMeshDict — fill in vertices, blocks, boundary"
echo "  2. Run: blockMesh"
echo "  3. Run: checkMesh"
echo "  4. Open in ParaView to verify geometry"
echo "  5. Set solver in system/controlDict and BCs in 0/U and 0/p before running"