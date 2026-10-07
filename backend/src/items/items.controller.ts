import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
} from '@nestjs/common';

import { UserId } from '../common/user-id.decorator';
import { ItemsService, type Item } from './items.service';

@Controller('items')
export class ItemsController {
  constructor(private readonly itemsService: ItemsService) {}

  @Get()
  list(@UserId() userId: string): Promise<{ items: Item[] }> {
    return this.itemsService.list(userId);
  }

  @Post()
  create(@UserId() userId: string, @Body() body: unknown): Promise<{ id: string }> {
    return this.itemsService.create(userId, body);
  }

  @Patch(':id')
  @HttpCode(204)
  setBought(
    @UserId() userId: string,
    @Param('id') itemId: string,
    @Body() body: unknown,
  ): Promise<void> {
    return this.itemsService.setBought(userId, itemId, body);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@UserId() userId: string, @Param('id') itemId: string): Promise<void> {
    return this.itemsService.remove(userId, itemId);
  }
}
