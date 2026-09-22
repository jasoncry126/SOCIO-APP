import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { MotionConfig } from "framer-motion";
import App from "./App";
import "./index.css";

const raiz = document.getElementById("raiz");
if (!raiz) throw new Error("Falta el div #raiz en index.html");

/* reducedMotion="user" hace que framer-motion respete el ajuste de "menos
   movimiento" del sistema, igual que la regla de CSS de index.css. Sin esto,
   las animaciones de JavaScript se seguirían viendo. */
createRoot(raiz).render(
  <StrictMode>
    <MotionConfig reducedMotion="user">
      <App />
    </MotionConfig>
  </StrictMode>,
);
