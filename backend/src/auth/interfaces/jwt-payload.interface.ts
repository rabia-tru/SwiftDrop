import { UserRole } from '../../common/enums';

export interface JwtPayload {
  sub: string; // rider id
  email: string;
  role: UserRole;
}
