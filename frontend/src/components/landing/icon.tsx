import type { CSSProperties } from "react";

interface IconProps {
	name: string;
	filled?: boolean;
	size?: number | string;
	className?: string;
	style?: CSSProperties;
}

export function Icon({
	name,
	filled = false,
	size = 20,
	className = "",
	style,
}: IconProps) {
	return (
		<span
			className={`material-symbols-rounded select-none leading-none ${className}`}
			style={{
				fontSize: typeof size === "number" ? `${size}px` : size,
				fontVariationSettings: filled
					? "'FILL' 1, 'wght' 400"
					: "'FILL' 0, 'wght' 400",
				...style,
			}}
			aria-hidden="true"
		>
			{name}
		</span>
	);
}
