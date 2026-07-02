"use client";

import { useMemo, useRef } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { RoundedBox } from "@react-three/drei";
import * as THREE from "three";

type Cube = {
  position: [number, number, number];
  scale: number;
  speed: number;
  offset: number;
  accent: boolean;
};

function seededRandom(seed: number) {
  let value = seed;
  return () => {
    value = (value * 16807) % 2147483647;
    return (value - 1) / 2147483646;
  };
}

function useCubes(count: number): Cube[] {
  return useMemo(() => {
    const random = seededRandom(42);
    const cubes: Cube[] = [];
    for (let i = 0; i < count; i += 1) {
      const radius = 2.6 + random() * 3.8;
      const angle = random() * Math.PI * 2;
      cubes.push({
        position: [
          Math.cos(angle) * radius * 1.35,
          (random() - 0.5) * 4.8,
          -1 - random() * 4,
        ],
        scale: 0.24 + random() * 0.55,
        speed: 0.25 + random() * 0.5,
        offset: random() * Math.PI * 2,
        accent: i % 6 === 0,
      });
    }
    return cubes;
  }, [count]);
}

function Field({ subdued }: { subdued: boolean }) {
  const group = useRef<THREE.Group>(null);
  const cubes = useCubes(34);
  const pointer = useRef({ x: 0, y: 0 });

  useFrame((state, delta) => {
    const target = state.pointer;
    pointer.current.x = THREE.MathUtils.lerp(pointer.current.x, target.x, 0.04);
    pointer.current.y = THREE.MathUtils.lerp(pointer.current.y, target.y, 0.04);
    if (group.current) {
      group.current.rotation.y += delta * 0.03;
      group.current.rotation.x = pointer.current.y * 0.08;
      group.current.rotation.z = pointer.current.x * -0.04;
      group.current.position.y = Math.sin(state.clock.elapsedTime * 0.18) * 0.15;
    }
  });

  return (
    <group ref={group}>
      {cubes.map((cube, i) => (
        <FloatingCube key={i} cube={cube} subdued={subdued} />
      ))}
    </group>
  );
}

function FloatingCube({ cube, subdued }: { cube: Cube; subdued: boolean }) {
  const mesh = useRef<THREE.Mesh>(null);
  const material = useRef<THREE.MeshPhysicalMaterial>(null);

  useFrame((state, delta) => {
    if (!mesh.current) return;
    const time = state.clock.elapsedTime;
    mesh.current.position.y =
      cube.position[1] + Math.sin(time * cube.speed + cube.offset) * 0.35;
    mesh.current.rotation.x += delta * 0.1 * cube.speed;
    mesh.current.rotation.y += delta * 0.14 * cube.speed;
    if (cube.accent && material.current) {
      const pulse = subdued
        ? 0.3 + Math.sin(time * 1.4 + cube.offset) * 0.15
        : 0.9 + Math.sin(time * 1.4 + cube.offset) * 0.55;
      material.current.emissiveIntensity = pulse;
    }
  });

  return (
    <mesh ref={mesh} position={cube.position} scale={cube.scale}>
      <RoundedBox args={[1, 1, 1]} radius={0.14} smoothness={3}>
        <meshPhysicalMaterial
          ref={material}
          color={cube.accent ? "#0a84ff" : "#1c2029"}
          emissive="#0a84ff"
          emissiveIntensity={cube.accent ? (subdued ? 0.35 : 1) : 0.02}
          roughness={0.16}
          metalness={0.4}
          clearcoat={1}
          clearcoatRoughness={0.2}
        />
      </RoundedBox>
    </mesh>
  );
}

export default function HeroCanvas({ active, subdued }: { active: boolean; subdued: boolean }) {
  return (
    <Canvas
      frameloop={active ? "always" : "never"}
      dpr={[1, 1.75]}
      camera={{ position: [0, 0, 9], fov: 42 }}
      gl={{ antialias: true, alpha: true, powerPreference: "low-power" }}
      style={{ pointerEvents: "none" }}
      aria-hidden
    >
      <fog attach="fog" args={["#08090c", 8, 17]} />
      <ambientLight intensity={subdued ? 0.4 : 0.5} />
      <directionalLight position={[4, 6, 6]} intensity={subdued ? 1 : 1.4} color="#dfe6ff" />
      <pointLight
        position={[-6, -2, 2]}
        intensity={subdued ? 8 : 26}
        color="#0a84ff"
        distance={16}
      />
      <pointLight position={[6, 3, 1]} intensity={subdued ? 4 : 12} color="#4aa3ff" distance={12} />
      <Field subdued={subdued} />
    </Canvas>
  );
}
