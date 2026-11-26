import { Form, Head } from '@inertiajs/react';
import InputError from '@/components/input-error';
import PasskeyVerify from '@/components/passkey-verify';
import PasswordInput from '@/components/password-input';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { store } from '@/routes/login';

type Props = {
    status?: string;
};

export default function Login({ status }: Props) {
    return (
        <>
            <Head title="Masuk" />

            <PasskeyVerify />

            <Form
                {...store.form()}
                resetOnSuccess={['password']}
                className="flex flex-col gap-4"
            >
                {({ processing, errors }) => (
                    <>
                        {status && (
                            <p className="rounded-xl bg-accent px-4 py-3 text-sm text-accent-foreground">
                                {status}
                            </p>
                        )}

                        <div className="grid gap-2">
                            <Label htmlFor="email">Email</Label>
                            <Input
                                id="email"
                                type="email"
                                name="email"
                                required
                                autoFocus
                                autoComplete="username"
                                placeholder="kamu@email.com"
                                className="h-11"
                            />
                            <InputError message={errors.email} />
                        </div>

                        <div className="grid gap-2">
                            <Label htmlFor="password">Password</Label>
                            <PasswordInput
                                id="password"
                                name="password"
                                required
                                autoComplete="current-password"
                                className="h-11"
                            />
                            <InputError message={errors.password} />
                        </div>

                        <div className="flex min-h-10 items-center gap-3">
                            <Checkbox id="remember" name="remember" />
                            <Label htmlFor="remember">
                                Ingat saya di browser ini
                            </Label>
                        </div>

                        <Button
                            type="submit"
                            className="h-11 w-full text-[15px] font-semibold"
                            disabled={processing}
                            data-test="login-button"
                        >
                            {processing && <Spinner />}
                            Masuk
                        </Button>
                    </>
                )}
            </Form>

            <p className="text-center text-xs leading-relaxed text-muted-foreground">
                Lupa password? Pakai{' '}
                <code className="font-mono text-foreground/80">
                    lumi:make-superadmin
                </code>{' '}
                di server.
            </p>
        </>
    );
}

Login.layout = {
    title: 'Masuk ke Console',
    description:
        'Khusus pemilik Lumi. Akun user biasa tidak bisa masuk di sini.',
};
