export enum UserRole {
  ADMIN = 'admin',
  RIDER = 'rider',
  CUSTOMER = 'customer',
  BUSINESS = 'business',
}

export enum RiderStatus {
  OFFLINE = 'offline',
  ONLINE = 'online',
  ON_DELIVERY = 'on_delivery',
}

export enum OrderStatus {
  PENDING = 'pending',
  ASSIGNED = 'assigned',
  ACCEPTED = 'accepted',
  PICKED_UP = 'picked_up',
  IN_TRANSIT = 'in_transit',
  DELIVERED = 'delivered',
  CANCELLED = 'cancelled',
}
