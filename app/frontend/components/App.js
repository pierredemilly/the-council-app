import { BrowserRouter, Route, Routes } from "react-router-dom";
import { AuthProvider } from "~/lib/auth";
import Conversation from "~/pages/Conversation";
import Login from "~/pages/Login";
import Signup from "~/pages/Signup";
import ForgotPassword from "~/pages/ForgotPassword";
import ResetPassword from "~/pages/ResetPassword";
import RequireAuth from "~/components/RequireAuth";
import AdminLayout from "~/pages/admin/AdminLayout";
import Settings from "~/pages/admin/Settings";
import Agents from "~/pages/admin/Agents";
import Sessions from "~/pages/admin/Sessions";
import SessionDetail from "~/pages/admin/SessionDetail";

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Conversation />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/reset-password" element={<ResetPassword />} />
          <Route
            path="/admin"
            element={
              <RequireAuth>
                <AdminLayout />
              </RequireAuth>
            }
          >
            <Route index element={<Settings />} />
            <Route path="characters" element={<Agents />} />
            <Route path="sessions" element={<Sessions />} />
            <Route path="sessions/:id" element={<SessionDetail />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
