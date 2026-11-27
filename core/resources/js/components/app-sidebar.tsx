import { Link } from '@inertiajs/react';
import {
    Boxes,
    LayoutGrid,
    ListOrdered,
    Settings2,
    ShieldCheck,
    Users,
    Wrench,
} from 'lucide-react';
import AppLogo from '@/components/app-logo';
import { NavMain } from '@/components/nav-main';
import { NavUser } from '@/components/nav-user';
import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
} from '@/components/ui/sidebar';
import { dashboard } from '@/routes/console';
import { index as audit } from '@/routes/console/audit';
import { index as logs } from '@/routes/console/logs';
import { index as providers } from '@/routes/console/providers';
import { edit as settings } from '@/routes/console/settings';
import { index as tools } from '@/routes/console/tools';
import { index as users } from '@/routes/console/users';
import type { NavItem } from '@/types';

const mainNavItems: NavItem[] = [
    { title: 'Dashboard', href: dashboard(), icon: LayoutGrid },
    { title: 'Users', href: users(), icon: Users },
    { title: 'Provider & model', href: providers(), icon: Boxes },
    { title: 'Tools & izin', href: tools(), icon: Wrench },
    { title: 'Audit log', href: audit(), icon: ShieldCheck },
    { title: 'Log pemakaian', href: logs(), icon: ListOrdered },
    { title: 'Pengaturan', href: settings(), icon: Settings2 },
];

export function AppSidebar() {
    return (
        <Sidebar collapsible="icon" variant="inset">
            <SidebarHeader>
                <SidebarMenu>
                    <SidebarMenuItem>
                        <SidebarMenuButton size="lg" asChild>
                            <Link href={dashboard()} prefetch>
                                <AppLogo />
                            </Link>
                        </SidebarMenuButton>
                    </SidebarMenuItem>
                </SidebarMenu>
            </SidebarHeader>

            <SidebarContent>
                <NavMain items={mainNavItems} />
            </SidebarContent>

            <SidebarFooter>
                <NavUser />
            </SidebarFooter>
        </Sidebar>
    );
}
