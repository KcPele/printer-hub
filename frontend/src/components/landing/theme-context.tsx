import {
	type CSSProperties,
	createContext,
	type ReactNode,
	useContext,
	useEffect,
	useState,
} from "react";

export type ThemeName = "mint" | "indigo" | "volt";

export interface ThemeTokens {
	name: string;
	p: string;
	onp: string;
	em: string;
	pe: string;
	bg: string;
	sf: string;
	inv: string;
	tx: string;
	mt: string;
	font: string;
	rc: string;
	rC: string;
	rb: string;
	sh: string;
	bd: string;
	line: string;
}

export const THEMES: Record<ThemeName, ThemeTokens> = {
	volt: {
		name: "Volt",
		p: "#FFFF1E",
		onp: "#212121",
		em: "#212121",
		pe: "#FFFF1E",
		bg: "#EEEEEE",
		sf: "#FFFFFF",
		inv: "#212121",
		tx: "#212121",
		mt: "#5B5B5B",
		font: "'Outfit', -apple-system, BlinkMacSystemFont, sans-serif",
		rc: "28px",
		rC: "36px",
		rb: "999px",
		sh: "none",
		bd: "1px solid #DCDCDC",
		line: "#DADADA",
	},
	indigo: {
		name: "Indigo",
		p: "#4856EB",
		onp: "#FFFFFF",
		em: "#4856EB",
		pe: "#A9B0FF",
		bg: "#EFF2FA",
		sf: "#FFFFFF",
		inv: "#1C1E2B",
		tx: "#1C1E2B",
		mt: "#585D73",
		font: "'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif",
		rc: "22px",
		rC: "28px",
		rb: "16px",
		sh: "none",
		bd: "1px solid #DDE2F0",
		line: "#DDE2F0",
	},
	mint: {
		name: "Mint",
		p: "#46D7B7",
		onp: "#0B3B32",
		em: "#0A7461",
		pe: "#46D7B7",
		bg: "#FFFFFF",
		sf: "#F7F7F7",
		inv: "#1A1A1A",
		tx: "#1A1A1A",
		mt: "#5E6366",
		font: "'Manrope', -apple-system, BlinkMacSystemFont, sans-serif",
		rc: "14px",
		rC: "18px",
		rb: "12px",
		sh: "none",
		bd: "1px solid #E2E5E8",
		line: "#E5E7E8",
	},
};

export function getThemeVars(theme: ThemeName): CSSProperties {
	const t = THEMES[theme] || THEMES.mint;
	return {
		"--p": t.p,
		"--onp": t.onp,
		"--em": t.em,
		"--pe": t.pe,
		"--bg": t.bg,
		"--sf": t.sf,
		"--inv": t.inv,
		"--tx": t.tx,
		"--mt": t.mt,
		"--font": t.font,
		"--rc": t.rc,
		"--rC": t.rC,
		"--rb": t.rb,
		"--sh": t.sh,
		"--bd": t.bd,
		"--line": t.line,
	} as CSSProperties;
}

interface ThemeContextValue {
	theme: ThemeName;
	setTheme: (theme: ThemeName) => void;
	currentTokens: ThemeTokens;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
	const [theme, setThemeState] = useState<ThemeName>("mint");

	useEffect(() => {
		try {
			const saved = localStorage.getItem(
				"printerhub-theme",
			) as ThemeName | null;
			if (
				saved &&
				(saved === "mint" || saved === "indigo" || saved === "volt")
			) {
				setThemeState(saved);
			}
		} catch {
			// Ignore localStorage errors
		}
	}, []);

	const setTheme = (newTheme: ThemeName) => {
		setThemeState(newTheme);
		try {
			localStorage.setItem("printerhub-theme", newTheme);
		} catch {
			// Ignore
		}
	};

	useEffect(() => {
		if (typeof document !== "undefined") {
			document.documentElement.setAttribute("data-theme", theme);
		}
	}, [theme]);

	const currentTokens = THEMES[theme] || THEMES.mint;

	return (
		<ThemeContext.Provider value={{ theme, setTheme, currentTokens }}>
			<div style={getThemeVars(theme)} className="w-full min-h-screen">
				{children}
			</div>
		</ThemeContext.Provider>
	);
}

export function useTheme(): ThemeContextValue {
	const context = useContext(ThemeContext);
	if (!context) {
		throw new Error("useTheme must be used within a ThemeProvider");
	}
	return context;
}
